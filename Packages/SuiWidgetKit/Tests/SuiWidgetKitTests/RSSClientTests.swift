import Foundation
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("RSSClient")
    struct RSSClientTests {

        private func makeClient() -> RSSClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            return RSSClient(http: http)
        }

        @Test func fetch_blog_parses_rss_fixture() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "rss-sui-blog.xml")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let client = makeClient()
            let items = try await client.fetchBlog()
            #expect(!items.isEmpty)
            #expect(items.allSatisfy { $0.source == .blog })
            #expect(items.allSatisfy { !$0.title.isEmpty && !$0.url.isEmpty })
        }

        @Test func fetch_github_releases_parses_atom_fixture() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "rss-mysten-releases.atom")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let client = makeClient()
            let items = try await client.fetchGitHubReleases()
            #expect(!items.isEmpty)
            #expect(items.allSatisfy { $0.source == .githubRelease })
        }

        @Test func fetch_merged_dedupes_sorts_and_caps_to_limit() async throws {
            MockURLProtocol.reset()
            let blog = try FixtureLoader.data(named: "rss-sui-blog.xml")
            let atom = try FixtureLoader.data(named: "rss-mysten-releases.atom")

            // Route by URL to serve the right feed.
            MockURLProtocol.handler = { request in
                let host = request.url?.host ?? ""
                if host.contains("blog.sui.io") {
                    return (200, blog, [:], nil)
                } else if host.contains("github.com") {
                    return (200, atom, [:], nil)
                }
                return (404, Data(), [:], nil)
            }

            let client = makeClient()
            let items = try await client.fetchMerged(limit: 30)
            #expect(!items.isEmpty)
            #expect(items.count <= 30)
            // Sorted descending by publishedAt.
            let dates = items.map(\.publishedAt)
            #expect(dates == dates.sorted(by: >))
            // Dedupe: every urlHash appears once.
            let hashes = Set(items.map(\.urlHash))
            #expect(hashes.count == items.count)
        }

        @Test func parse_failure_throws_parseFailed() async throws {
            MockURLProtocol.reset()
            let garbage = Data("<not really xml".utf8)
            MockURLProtocol.handler = { _ in (200, garbage, [:], nil) }

            let client = makeClient()
            do {
                _ = try await client.fetchBlog()
                #expect(Bool(false), "expected parseFailed throw")
            } catch let err as RSSError {
                if case .parseFailed = err { /* OK */ } else {
                    #expect(Bool(false), "wrong error case: \(err)")
                }
            }
        }
    }
}
