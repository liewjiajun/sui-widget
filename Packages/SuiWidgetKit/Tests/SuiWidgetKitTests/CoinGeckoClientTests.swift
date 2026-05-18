import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("CoinGeckoClient")
    struct CoinGeckoClientTests {

        private func makeContext() throws -> ModelContext {
            let container = try SwiftDataStack.makeContainer(inMemory: true)
            return ModelContext(container)
        }

        private func makeClient(
            context: ModelContext,
            clock: InjectableClock = .system
        ) -> CoinGeckoClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            return CoinGeckoClient(http: http, modelContext: context, clock: clock)
        }

        @Test func refresh_coin_list_filters_and_persists_sui_platform_entries() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "coingecko-coins-list-sui-platform.json")
            // NOTE: The committed fixture is already pre-filtered to platforms.sui entries.
            // The client's own filter call is a no-op on this fixture but exercises the codepath.
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let context = try makeContext()
            let client = makeClient(context: context)
            let mappings = try await client.refreshCoinList(force: true)
            #expect(!mappings.isEmpty)
            // Every mapping in the returned list should have a non-empty coinType.
            #expect(mappings.allSatisfy { !$0.coinType.isEmpty })

            // The persisted CachedCoinListEntry rows should match.
            let stored = try context.fetch(FetchDescriptor<CachedCoinListEntry>())
            #expect(stored.count == mappings.count)

            // AppSettings.lastCoinListFetchedAt should be set.
            let settings = try context.fetch(FetchDescriptor<AppSettings>()).first
            #expect(settings?.lastCoinListFetchedAt != nil)
        }

        @Test func refresh_coin_list_uses_cache_when_fresh() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "coingecko-coins-list-sui-platform.json")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            // First call: networked.
            let context = try makeContext()
            let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
            let clock = InjectableClock.fixed(fixedNow)
            let client = makeClient(context: context, clock: clock)
            _ = try await client.refreshCoinList(force: true)
            let requestsAfterFirst = MockURLProtocol.requestsObserved.count

            // Second call (no force, same clock instant): should hit cache and skip network.
            _ = try await client.refreshCoinList(force: false)
            #expect(MockURLProtocol.requestsObserved.count == requestsAfterFirst, "second refresh should be a cache hit")
        }

        @Test func refresh_coin_list_refetches_after_ttl() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "coingecko-coins-list-sui-platform.json")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            // First fetch at T0.
            let context = try makeContext()
            let t0 = Date(timeIntervalSince1970: 1_700_000_000)
            final class MutableDate: @unchecked Sendable { var value: Date; init(_ v: Date) { value = v } }
            let storage = MutableDate(t0)
            let clock = InjectableClock(now: { storage.value })
            let client = makeClient(context: context, clock: clock)
            _ = try await client.refreshCoinList(force: true)
            let observedAfterFirst = MockURLProtocol.requestsObserved.count

            // Advance past TTL.
            storage.value = t0.addingTimeInterval(25 * 60 * 60) // 25 hours
            _ = try await client.refreshCoinList(force: false)
            #expect(MockURLProtocol.requestsObserved.count > observedAfterFirst, "should refetch after TTL")
        }

        @Test func fetch_prices_decodes_markets_fixture() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "coingecko-coins-markets-multi.json")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let context = try makeContext()
            let client = makeClient(context: context)
            let prices = try await client.fetchPrices(coingeckoIds: ["sui", "usd-coin", "tether"])
            #expect(prices.count == 3)
            #expect(prices.contains(where: { $0.id == "sui" }))
        }

        @Test func fetch_prices_empty_ids_returns_empty_without_network() async throws {
            MockURLProtocol.reset()
            // No handler set — any network call would fail.
            let context = try makeContext()
            let client = makeClient(context: context)
            let prices = try await client.fetchPrices(coingeckoIds: [])
            #expect(prices.isEmpty)
            #expect(MockURLProtocol.requestsObserved.isEmpty)
        }

        @Test func rate_limit_response_throws_rateLimitExceeded() async throws {
            MockURLProtocol.reset()
            MockURLProtocol.handler = { _ in (429, Data(), [:], nil) }

            let context = try makeContext()
            let client = makeClient(context: context)
            do {
                _ = try await client.refreshCoinList(force: true)
                #expect(Bool(false), "expected rateLimitExceeded throw")
            } catch let err as CoinGeckoError {
                #expect(err == .rateLimitExceeded)
            }
        }
    }
}
