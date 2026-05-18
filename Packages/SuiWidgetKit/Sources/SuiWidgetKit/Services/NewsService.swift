import Foundation
import SwiftData

/// Refreshes the Sui blog news feed. Maintains a 30-minute cache window guarded
/// by `AppSettings.lastNewsFetchedAt` and a 30-item cap.
///
/// V1 intentionally surfaces only editorial blog posts in the News tab; GitHub
/// releases are technical/changelog content and were removed from this feed.
/// `RSSClient.fetchGitHubReleases` and `fetchMerged` remain available in the
/// data layer for a future Developer Updates surface.
public struct NewsService {
    public let modelContext: ModelContext
    public let rss: RSSClient
    public let cacheTTL: TimeInterval
    public let clock: InjectableClock

    public init(
        modelContext: ModelContext,
        rss: RSSClient = RSSClient(),
        cacheTTL: TimeInterval = 30 * 60,   // 30 min
        clock: InjectableClock = .system
    ) {
        self.modelContext = modelContext
        self.rss = rss
        self.cacheTTL = cacheTTL
        self.clock = clock
    }

    /// Refreshes the news feed. Returns cached rows if `AppSettings.lastNewsFetchedAt`
    /// is within `cacheTTL`. Otherwise fetches the Sui blog feed, upserts by
    /// `urlHash`, deletes rows that fall outside the top 30, and updates the timestamp.
    @discardableResult
    public func refresh(force: Bool = false) async throws -> [CachedNewsItem] {
        let settings = try fetchOrCreateAppSettings()
        let now = clock.now()
        if !force,
           let last = settings.lastNewsFetchedAt,
           now.timeIntervalSince(last) < cacheTTL {
            return try cachedNewsSorted()
        }

        // Blog-only: GitHub releases are technical changelog content and are
        // excluded from the News tab. `RSSClient.fetchBlog()` returns all items
        // unsorted, so we sort by publishedAt desc and cap to 30 here.
        let blog = try await rss.fetchBlog()
        let raw = Array(blog.sorted { $0.publishedAt > $1.publishedAt }.prefix(30))
        let topHashes = Set(raw.map(\.urlHash))

        // Delete existing rows that are not in the new top-30 set.
        let existing = try modelContext.fetch(FetchDescriptor<CachedNewsItem>())
        for row in existing where !topHashes.contains(row.id) {
            modelContext.delete(row)
        }

        // Build map of surviving existing rows for upsert.
        let existingByHash: [String: CachedNewsItem] = Dictionary(
            uniqueKeysWithValues: existing.compactMap { row in
                topHashes.contains(row.id) ? (row.id, row) : nil
            }
        )
        for item in raw {
            if let row = existingByHash[item.urlHash] {
                row.title = item.title
                row.url = item.url
                row.publishedAt = item.publishedAt
                row.source = item.source
                row.summary = item.summary
            } else {
                modelContext.insert(CachedNewsItem(
                    id: item.urlHash,
                    title: item.title,
                    url: item.url,
                    publishedAt: item.publishedAt,
                    source: item.source,
                    summary: item.summary
                ))
            }
        }

        settings.lastNewsFetchedAt = now
        try modelContext.save()

        return try cachedNewsSorted()
    }

    // MARK: - Helpers

    private func cachedNewsSorted() throws -> [CachedNewsItem] {
        let descriptor = FetchDescriptor<CachedNewsItem>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchOrCreateAppSettings() throws -> AppSettings {
        let existing = try modelContext.fetch(FetchDescriptor<AppSettings>())
        if let s = existing.first { return s }
        let new = AppSettings()
        modelContext.insert(new)
        try modelContext.save()
        return new
    }
}
