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
                // DeFiLlama is primary; return empty so these tests deterministically
                // exercise the CoinGecko fallback path they were written for.
                if host.contains("llama.fi") {
                    return (200, Data(#"{"coins":{}}"#.utf8), [:], nil)
                }
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

        /// DeFiLlama client bound to the mocked session, so tests never hit the
        /// live `coins.llama.fi` (the default `DeFiLlamaClient()` uses `.shared`).
        private func makeDeFiLlama() -> DeFiLlamaClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            return DeFiLlamaClient(http: http)
        }

        @Test func refresh_builds_portfolio_with_tracked_and_untracked_tokens() async throws {
            MockURLProtocol.reset()
            try setupHandler()
            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = PortfolioService(
                modelContext: context,
                sui: makeRPC(),
                coinGecko: makeCoinGecko(context),
                deFiLlama: makeDeFiLlama()
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
                coinGecko: makeCoinGecko(context),
                deFiLlama: makeDeFiLlama()
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
                coinGecko: makeCoinGecko(context),
                deFiLlama: makeDeFiLlama()
            )

            _ = try await service.refresh(walletId: walletId)
            _ = try await service.refresh(walletId: walletId)

            let portfolios = try context.fetch(FetchDescriptor<CachedPortfolio>())
            #expect(portfolios.count == 1, "second refresh should replace, not duplicate")
        }

        /// A liquid-staking token (haSUI) must be priced via its SUI underlying,
        /// counted in the portfolio total, and tagged so the Earning section can
        /// show where the user's tokens are deployed. This is the end-to-end proof
        /// of the "show where my tokens are staked/lent" requirement.
        @Test func defi_lst_is_priced_via_underlying_and_tagged() async throws {
            MockURLProtocol.reset()
            let haSUI = "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI"
            let balancesJSON = """
            {"jsonrpc":"2.0","id":1,"result":[
              {"coinType":"\(haSUI)","coinObjectCount":1,"totalBalance":"5000000000"}
            ]}
            """
            // DeFiLlama is primary and prices haSUI directly (keyed by coin type),
            // returning its decimals too — so no CoinGecko or metadata RPC is hit.
            // Price it at $1.45 (+2% 24h). 5 haSUI × $1.45 = $7.25.
            let llamaPrices = """
            {"coins":{"sui:\(haSUI)":{"decimals":9,"symbol":"haSUI","price":1.45,"timestamp":1,"confidence":0.99}}}
            """
            let llamaPct = """
            {"coins":{"sui:\(haSUI)":2.0}}
            """

            MockURLProtocol.handler = { request in
                let host = request.url?.host ?? ""
                if host.contains("llama.fi") {
                    let path = request.url?.path ?? ""
                    if path.contains("/percentage/") { return (200, Data(llamaPct.utf8), [:], nil) }
                    return (200, Data(llamaPrices.utf8), [:], nil)
                }
                if host.contains("coingecko.com") {
                    // Should not be reached — DeFiLlama already priced haSUI.
                    return (200, Data(#"[]"#.utf8), [:], nil)
                }
                let body = Self.decodeBody(request)
                if body.contains("suix_getAllBalances") {
                    return (200, Data(balancesJSON.utf8), [:], nil)
                }
                if body.contains("suix_getStakes") {
                    return (200, Data(#"{"jsonrpc":"2.0","id":1,"result":[]}"#.utf8), [:], nil)
                }
                return (200, Data(#"{"jsonrpc":"2.0","id":1,"result":null}"#.utf8), [:], nil)
            }

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = PortfolioService(
                modelContext: context,
                sui: makeRPC(),
                coinGecko: makeCoinGecko(context),
                deFiLlama: makeDeFiLlama()
            )

            let portfolio = try await service.refresh(walletId: walletId)
            let position = try #require(portfolio.tokens.first(where: { $0.symbol == "haSUI" }))
            // Recognised as a Haedal liquid-staking position …
            #expect(position.dappName == "Haedal")
            #expect(position.defiCategory == "Liquid staking")
            #expect(position.isDeFiPosition)
            #expect(position.symbol == "haSUI")
            // … priced via DeFiLlama, so its value lands in the total.
            #expect(position.isTracked)
            #expect(position.priceUSD == Decimal(string: "1.45"))
            // 5 haSUI × $1.45 = $7.25 contributed to the portfolio total.
            #expect(position.valueUSD == Decimal(string: "7.25"))
            #expect(portfolio.totalUSD == Decimal(string: "7.25"))
        }

        @Test func kai_ytoken_priced_via_underlying_and_tagged() async throws {
            MockURLProtocol.reset()
            // Kai Finance ySUI (Single-Asset-Vault receipt). DeFiLlama does NOT
            // price yTokens, so this exercises the underlying-asset fallback:
            // ySUI → SUI price, tagged as a Kai lending position.
            let ySUI = "0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ysui::YSUI"
            let suiCanonical = CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI")
            let balancesJSON = """
            {"jsonrpc":"2.0","id":1,"result":[
              {"coinType":"\(ySUI)","coinObjectCount":1,"totalBalance":"10000000000"}
            ]}
            """
            // DeFiLlama prices SUI (the underlying) but returns nothing for ySUI.
            let llamaPrices = """
            {"coins":{"sui:\(suiCanonical)":{"decimals":9,"symbol":"SUI","price":2.0,"timestamp":1,"confidence":0.99}}}
            """

            MockURLProtocol.handler = { request in
                let host = request.url?.host ?? ""
                if host.contains("llama.fi") {
                    let path = request.url?.path ?? ""
                    if path.contains("/percentage/") { return (200, Data(#"{"coins":{}}"#.utf8), [:], nil) }
                    return (200, Data(llamaPrices.utf8), [:], nil)
                }
                if host.contains("coingecko.com") { return (200, Data(#"[]"#.utf8), [:], nil) }
                let body = Self.decodeBody(request)
                if body.contains("suix_getAllBalances") {
                    return (200, Data(balancesJSON.utf8), [:], nil)
                }
                // ySUI has 9 decimals on-chain — used because DeFiLlama priced via
                // the underlying and didn't report ySUI's own decimals.
                if body.contains("suix_getCoinMetadata") {
                    return (200, Data(#"{"jsonrpc":"2.0","id":1,"result":{"decimals":9,"name":"Kai Vault SUI","symbol":"ySUI","description":"","iconUrl":null}}"#.utf8), [:], nil)
                }
                return (200, Data(#"{"jsonrpc":"2.0","id":1,"result":null}"#.utf8), [:], nil)
            }

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = PortfolioService(
                modelContext: context,
                sui: makeRPC(),
                coinGecko: makeCoinGecko(context),
                deFiLlama: makeDeFiLlama()
            )

            let portfolio = try await service.refresh(walletId: walletId)
            let position = try #require(portfolio.tokens.first(where: { $0.dappName == "Kai" }))
            #expect(position.defiCategory == "Lending")
            #expect(position.symbol == "ySUI")
            #expect(position.isTracked)
            // 10 ySUI × $2.00 (underlying SUI) = $20.00.
            #expect(position.priceUSD == Decimal(string: "2.0"))
            #expect(position.valueUSD == Decimal(string: "20.0"))
        }
    }
}
