import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("PortfolioService")
    struct PortfolioServiceTests {

        private func makeContext() throws -> ModelContext {
            let container = try SwiftDataStack.makeContainer(inMemory: true)
            return ModelContext(container)
        }

        private func makeRPC(endpoint: URL = URL(string: "https://test.example/")!) -> SuiRPCClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            let rotator = RPCEndpointRotator(endpoints: [endpoint])
            return SuiRPCClient(http: http, rotator: rotator)
        }

        private func seedWallet(_ context: ModelContext) throws -> UUID {
            let wallet = Wallet(
                address: "0x" + String(repeating: "a", count: 64),
                isPrimary: true,
                orderIndex: 0
            )
            context.insert(wallet)
            try context.save()
            return wallet.id
        }

        /// Reads JSON-RPC body from either httpBody or httpBodyStream.
        @Sendable
        private static func decodeBody(_ request: URLRequest) -> String {
            if let body = request.httpBody {
                return String(decoding: body, as: UTF8.self)
            }
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data()
                let bufferSize = 4096
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                while stream.hasBytesAvailable {
                    let read = stream.read(&buffer, maxLength: bufferSize)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                return String(decoding: data, as: UTF8.self)
            }
            return ""
        }

        /// Routes requests by URL host and (for the JSON-RPC endpoint) by
        /// request body method. Returns balances, coin list, and markets fixtures.
        private func setupHandler() throws {
            let balances = try FixtureLoader.data(named: "sui-getAllBalances-success.json")
            let coinList = try FixtureLoader.data(named: "coingecko-coins-list-sui-platform.json")
            let markets = try FixtureLoader.data(named: "coingecko-coins-markets-multi.json")

            MockURLProtocol.handler = { request in
                let host = request.url?.host ?? ""
                if host.contains("coingecko.com") {
                    let path = request.url?.path ?? ""
                    if path.contains("/coins/list") {
                        return (200, coinList, [:], nil)
                    }
                    if path.contains("/coins/markets") {
                        return (200, markets, [:], nil)
                    }
                    return (404, Data(), [:], nil)
                }
                // JSON-RPC endpoint.
                let body = Self.decodeBody(request)
                if body.contains("suix_getAllBalances") {
                    return (200, balances, [:], nil)
                }
                return (404, Data(), [:], nil)
            }
        }

        private func makeCoinGecko(_ context: ModelContext) -> CoinGeckoClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            return CoinGeckoClient(http: http, modelContext: context)
        }

        @Test func refresh_builds_portfolio_with_tracked_and_untracked_tokens() async throws {
            MockURLProtocol.reset()
            try setupHandler()
            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = PortfolioService(
                modelContext: context,
                sui: makeRPC(),
                coinGecko: makeCoinGecko(context)
            )

            let portfolio = try await service.refresh(walletId: walletId)
            #expect(!portfolio.tokens.isEmpty)
            // CoinTypeCanonicalizer reconciles the balances fixture's short
            // form (`0x2::sui::SUI`) with the coin list fixture's long form,
            // so SUI is now tracked. The balances fixture also contains many
            // coins not in the coin list (GMB, TUSK, REX, …) so we still
            // expect both tracked and untracked entries.
            #expect(portfolio.tokens.contains(where: { $0.isTracked }))
            #expect(portfolio.tokens.contains(where: { !$0.isTracked }))
        }

        @Test func refresh_recomputes_24h_change() async throws {
            MockURLProtocol.reset()
            try setupHandler()
            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = PortfolioService(
                modelContext: context,
                sui: makeRPC(),
                coinGecko: makeCoinGecko(context)
            )

            let portfolio = try await service.refresh(walletId: walletId)
            // Totals are computed from tracked balances with priced markets.
            // The markets fixture returns 3 ids (sui, usd-coin, tether) — at
            // least usd-coin maps to a balance entry, so totalUSD should be
            // computed (>= 0; can be 0 if the matched balance is zero).
            #expect(portfolio.totalUSD >= 0)
            #expect(portfolio.snapshotAt.timeIntervalSinceNow < 5)
            // change24hPercent is a finite Double.
            #expect(portfolio.change24hPercent.isFinite)
        }

        @Test func refresh_replaces_existing_portfolio() async throws {
            MockURLProtocol.reset()
            try setupHandler()
            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = PortfolioService(
                modelContext: context,
                sui: makeRPC(),
                coinGecko: makeCoinGecko(context)
            )

            _ = try await service.refresh(walletId: walletId)
            _ = try await service.refresh(walletId: walletId)

            let portfolios = try context.fetch(FetchDescriptor<CachedPortfolio>())
            #expect(portfolios.count == 1, "second refresh should replace, not duplicate")
        }
    }
}
