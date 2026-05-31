import Foundation
import SwiftData
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class NewsViewModel {
    var loadState: LoadState = .idle
    var items: [CachedNewsItem] = []

    private let modelContext: ModelContext
    private let newsService: NewsService

    // Local-only read tracking (in-app), persisted to UserDefaults.
    private static let readKey = "readNewsItemIDs"
    private var readIDs: Set<String>

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.newsService = NewsService(modelContext: modelContext, rss: RSSClient())
        let stored = UserDefaults.standard.stringArray(forKey: Self.readKey) ?? []
        self.readIDs = Set(stored)
    }

    func isRead(_ id: String) -> Bool { readIDs.contains(id) }

    func markRead(_ id: String) {
        guard readIDs.insert(id).inserted else { return }
        UserDefaults.standard.set(Array(readIDs), forKey: Self.readKey)
    }

    func load() {
        let descriptor = FetchDescriptor<CachedNewsItem>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        items = (try? modelContext.fetch(descriptor)) ?? []
        loadState = items.isEmpty
            ? .empty(message: "Pull down to fetch the latest Sui ecosystem news.")
            : .loaded
    }

    func refresh() async {
        loadState = .loading
        do {
            _ = try await newsService.refresh(force: true)
            load()
        } catch {
            loadState = items.isEmpty
                ? .error(message: error.localizedDescription, retry: nil)
                : .error(message: "couldn't refresh — showing cached", retry: nil)
        }
    }

    var featured: CachedNewsItem? { items.first }
    var rest: [CachedNewsItem] { Array(items.dropFirst()) }
}
