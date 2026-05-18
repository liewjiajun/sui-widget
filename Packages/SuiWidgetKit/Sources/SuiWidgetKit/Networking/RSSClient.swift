import Foundation
import FeedKit
import CryptoKit

/// Plain value type representing one RSS/Atom item, before persistence shape conversion.
public struct RawNewsItem: Equatable, Hashable, Sendable {
    public let urlHash: String           // SHA256 hex of url string — used as id
    public let title: String
    public let url: String
    public let publishedAt: Date
    public let source: NewsSource
    public let summary: String?
    public let heroImageURL: String?

    public init(
        title: String,
        url: String,
        publishedAt: Date,
        source: NewsSource,
        summary: String? = nil,
        heroImageURL: String? = nil
    ) {
        self.urlHash = RawNewsItem.hashURL(url)
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.source = source
        self.summary = summary
        self.heroImageURL = heroImageURL
    }

    static func hashURL(_ url: String) -> String {
        let digest = SHA256.hash(data: Data(url.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public struct RSSClient: Sendable {
    public static let suiBlogURL = URL(string: "https://blog.sui.io/rss/")!
    public static let mystenReleasesURL = URL(string: "https://github.com/MystenLabs/sui/releases.atom")!

    public let http: HTTPClient

    public init(http: HTTPClient = HTTPClient()) {
        self.http = http
    }

    public func fetchBlog() async throws -> [RawNewsItem] {
        try await fetchAndParse(url: Self.suiBlogURL, source: .blog)
    }

    public func fetchGitHubReleases() async throws -> [RawNewsItem] {
        try await fetchAndParse(url: Self.mystenReleasesURL, source: .githubRelease)
    }

    /// Fetches both feeds in parallel via async let, merges, sorts by publishedAt desc,
    /// dedupes by urlHash, returns top `limit`.
    public func fetchMerged(limit: Int = 30) async throws -> [RawNewsItem] {
        async let blog = fetchBlog()
        async let releases = fetchGitHubReleases()

        let merged = try await blog + releases
        // Dedupe by urlHash, preserving first occurrence (highest pubDate wins after sort).
        let sorted = merged.sorted { $0.publishedAt > $1.publishedAt }
        var seen: Set<String> = []
        var unique: [RawNewsItem] = []
        for item in sorted {
            if !seen.contains(item.urlHash) {
                seen.insert(item.urlHash)
                unique.append(item)
            }
            if unique.count == limit { break }
        }
        return unique
    }

    private func fetchAndParse(url: URL, source: NewsSource) async throws -> [RawNewsItem] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/xml, application/rss+xml, application/atom+xml", forHTTPHeaderField: "accept")
        request.timeoutInterval = 15

        let data: Data
        do {
            let (body, response) = try await http.send(request)
            guard (200...299).contains(response.statusCode) else {
                throw RSSError.http(.clientError(response.statusCode))
            }
            data = body
        } catch let err as HTTPClientError {
            throw RSSError.http(err)
        }

        let parser = FeedParser(data: data)
        let result = parser.parse()

        switch result {
        case .success(let feed):
            switch feed {
            case .rss(let rss):
                let items = (rss.items ?? []).compactMap { item -> RawNewsItem? in
                    guard let title = item.title, let link = item.link else { return nil }
                    let published = item.pubDate ?? Date()
                    return RawNewsItem(
                        title: title,
                        url: link,
                        publishedAt: published,
                        source: source,
                        summary: item.description,
                        heroImageURL: Self.extractImageURL(from: item)
                    )
                }
                if items.isEmpty { throw RSSError.noEntries }
                return items
            case .atom(let atom):
                let entries = (atom.entries ?? []).compactMap { entry -> RawNewsItem? in
                    guard let title = entry.title else { return nil }
                    // Atom links are typed; prefer rel="alternate" or first href.
                    let link = entry.links?.first(where: { $0.attributes?.rel == "alternate" || $0.attributes?.rel == nil })?.attributes?.href
                        ?? entry.links?.first?.attributes?.href
                    guard let link else { return nil }
                    let published = entry.updated ?? entry.published ?? Date()
                    return RawNewsItem(
                        title: title,
                        url: link,
                        publishedAt: published,
                        source: source,
                        summary: entry.summary?.value,
                        heroImageURL: Self.extractImageURL(from: entry)
                    )
                }
                if entries.isEmpty { throw RSSError.noEntries }
                return entries
            case .json:
                throw RSSError.parseFailed(detail: "Unexpected JSON feed; expected RSS or Atom.")
            }
        case .failure(let error):
            throw RSSError.parseFailed(detail: String(describing: error))
        }
    }

    // MARK: - Hero image extraction

    /// Picks a hero image URL for a Ghost/WordPress/Substack-style RSS item.
    /// Priority: media:content[medium=image] → media:thumbnail → image enclosure →
    /// first <img> in content:encoded → first <img> in description.
    static func extractImageURL(from item: RSSFeedItem) -> String? {
        if let url = item.media?.mediaContents?.first(where: {
            ($0.attributes?.medium ?? "image") == "image"
        })?.attributes?.url, !url.isEmpty {
            return url
        }
        if let url = item.media?.mediaThumbnails?.first?.attributes?.url, !url.isEmpty {
            return url
        }
        if let enclosure = item.enclosure?.attributes,
           let url = enclosure.url,
           (enclosure.type ?? "image/").hasPrefix("image") {
            return url
        }
        if let html = item.content?.contentEncoded,
           let url = firstImageURL(inHTML: html) {
            return url
        }
        if let html = item.description, let url = firstImageURL(inHTML: html) {
            return url
        }
        return nil
    }

    /// Atom variant. GitHub releases atoms don't carry images, but the same
    /// media: namespace is supported by FeedKit on AtomFeedEntry; fall back to
    /// scanning the entry content/summary HTML.
    static func extractImageURL(from entry: AtomFeedEntry) -> String? {
        if let url = entry.media?.mediaContents?.first(where: {
            ($0.attributes?.medium ?? "image") == "image"
        })?.attributes?.url, !url.isEmpty {
            return url
        }
        if let url = entry.media?.mediaThumbnails?.first?.attributes?.url, !url.isEmpty {
            return url
        }
        if let html = entry.content?.value, let url = firstImageURL(inHTML: html) {
            return url
        }
        if let html = entry.summary?.value, let url = firstImageURL(inHTML: html) {
            return url
        }
        return nil
    }

    /// Crude but correct enough for Ghost/Substack-style blog HTML: extract the
    /// first `<img src="…">` URL. Handles single or double quotes and arbitrary
    /// attributes between `<img` and `src=`.
    static func firstImageURL(inHTML html: String) -> String? {
        let pattern = #"<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let srcRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let url = String(html[srcRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }
}
