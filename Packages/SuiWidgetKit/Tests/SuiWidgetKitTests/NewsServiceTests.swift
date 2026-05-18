import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("NewsService")
    struct NewsServiceTests {

        private func makeContext() throws -> ModelContext {
            let container = try SwiftDataStack.makeContainer(inMemory: true)
            return ModelContext(container)
        }

        /// Blog-only handler — any non-blog host returns 404 so that if a
        /// regression re-introduces a GitHub-releases fetch, the test
        /// surfaces the unexpected request.
        private func setupBlogOnlyFeed() throws {
            let blog = try FixtureLoader.data(named: "rss-sui-blog.xml")
            MockURLProtocol.handler = { request in
                let host = request.url?.host ?? ""
                if host.contains("blog.sui.io") { return (200, blog, [:], nil) }
                return (404, Data(), [:], nil)
            }
        }

        @Test func refresh_populates_cache_and_sets_timestamp() async throws {
            MockURLProtocol.reset()
            try setupBlogOnlyFeed()
            let context = try makeContext()
            let service = NewsService(
                modelContext: context,
                rss: RSSClient(http: HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 }))
            )

            let result = try await service.refresh(force: true)
            #expect(!result.isEmpty)
            #expect(result.count <= 30)

            let settings = try context.fetch(FetchDescriptor<AppSettings>()).first
            #expect(settings?.lastNewsFetchedAt != nil)
        }

        @Test func refresh_uses_cache_when_fresh() async throws {
            MockURLProtocol.reset()
            try setupBlogOnlyFeed()
            let context = try makeContext()
            let service = NewsService(
                modelContext: context,
                rss: RSSClient(http: HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 }))
            )

            _ = try await service.refresh(force: true)
            let observedAfterFirst = MockURLProtocol.requestsObserved.count
            _ = try await service.refresh(force: false)
            #expect(MockURLProtocol.requestsObserved.count == observedAfterFirst)
        }

        @Test func refresh_returns_results_sorted_by_publishedAt_desc() async throws {
            MockURLProtocol.reset()
            try setupBlogOnlyFeed()
            let context = try makeContext()
            let service = NewsService(
                modelContext: context,
                rss: RSSClient(http: HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 }))
            )

            let result = try await service.refresh(force: true)
            let dates = result.map(\.publishedAt)
            #expect(dates == dates.sorted(by: >))
            // News tab is blog-only — guard against a regression that
            // re-introduces GitHub release fetching.
            #expect(result.allSatisfy { $0.source == .blog })
        }
    }
}
