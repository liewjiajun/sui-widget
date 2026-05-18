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

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.newsService = NewsService(modelContext: modelContext, rss: RSSClient())
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
