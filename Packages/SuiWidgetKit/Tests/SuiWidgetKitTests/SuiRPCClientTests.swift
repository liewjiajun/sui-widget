import Foundation
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("SuiRPCClient")
    struct SuiRPCClientTests {

        private func makeClient(endpoint: URL = URL(string: "https://test.example/")!) -> SuiRPCClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            let rotator = RPCEndpointRotator(endpoints: [endpoint])
            return SuiRPCClient(http: http, rotator: rotator)
        }

        /// Convenience: registers a handler that returns the named fixture for any URL.
        private func stubFixture(_ name: String) throws {
            let body = try FixtureLoader.data(named: name)
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }
        }

        private static let walletAddress = SuiAddress(
            rawValue: "0xe6d2886da571e044dd3873d40eba75aa5610c51618f0c48fa0ca376d492d56a8"
        )!

        @Test func get_all_balances_parses_fixture() async throws {
            MockURLProtocol.reset()
            try stubFixture("sui-getAllBalances-success.json")

            let client = makeClient()
            let balances = try await client.getAllBalances(owner: Self.walletAddress)
            #expect(!balances.isEmpty)
            // SUI balance should be present.
            #expect(balances.contains(where: { $0.coinType.contains("::sui::SUI") }))
            // totalBalance decoded as Decimal — must be non-negative.
            for balance in balances {
                #expect(balance.totalBalance >= 0)
            }
        }

        @Test func get_coin_metadata_parses_fixture() async throws {
            MockURLProtocol.reset()
            try stubFixture("sui-getCoinMetadata-sui.json")

            let client = makeClient()
            let meta = try await client.getCoinMetadata(coinType: "0x2::sui::SUI")
            #expect(meta.symbol == "SUI")
            #expect(meta.decimals == 9)
            #expect(meta.name == "Sui")
            // The mainnet fixture has iconUrl as "" — adapter normalises empty to nil.
            #expect(meta.iconUrl == nil)
        }

        @Test func get_owned_objects_parses_fixture() async throws {
            MockURLProtocol.reset()
            try stubFixture("sui-getOwnedObjects-page1.json")

            let client = makeClient()
            let page = try await client.getOwnedObjects(owner: Self.walletAddress, limit: 10)
            #expect(!page.data.isEmpty)
            #expect(page.hasNextPage == true)
            #expect(page.nextCursor != nil)
            // Every wrapper must carry inner object data with at least an objectId.
            for wrapper in page.data {
                #expect(wrapper.data?.objectId.hasPrefix("0x") == true)
            }
        }

        @Test func get_stakes_parses_fixture() async throws {
            MockURLProtocol.reset()
            try stubFixture("sui-getStakes-success.json")

            let client = makeClient()
            let stakes = try await client.getStakes(owner: Self.walletAddress)
            #expect(!stakes.isEmpty)
            let firstStake = try #require(stakes.first?.stakes.first)
            #expect(firstStake.principal > 0)
            #expect(firstStake.status == "Active")
            #expect(firstStake.estimatedReward != nil)
        }

        @Test func get_latest_sui_system_state_parses_fixture() async throws {
            MockURLProtocol.reset()
            try stubFixture("sui-getLatestSuiSystemState-truncated.json")

            let client = makeClient()
            let state = try await client.getLatestSuiSystemState()
            #expect(!state.epoch.isEmpty)
            #expect(state.activeValidators.count == 5)
            let first = try #require(state.activeValidators.first)
            #expect(!first.name.isEmpty)
            #expect(!first.commissionRate.isEmpty)
            #expect(first.suiAddress.hasPrefix("0x"))
        }

        @Test func resolve_name_service_address_parses_fixture() async throws {
            MockURLProtocol.reset()
            try stubFixture("sui-resolveNameServiceAddress-success.json")

            let client = makeClient()
            let addr = try await client.resolveNameServiceAddress(name: "validator.sui")
            #expect(addr != nil)
            #expect(addr?.rawValue.hasPrefix("0x") == true)
        }

        @Test func resolve_name_service_names_parses_fixture() async throws {
            MockURLProtocol.reset()
            try stubFixture("sui-resolveNameServiceNames-success.json")

            let client = makeClient()
            let names = try await client.resolveNameServiceNames(address: Self.walletAddress)
            // Just assert decoding didn't throw — fixture has one .sui name.
            #expect(names.contains(where: { $0.hasSuffix(".sui") }))
        }

        @Test func rpc_error_response_throws_typed_error() async throws {
            MockURLProtocol.reset()
            let errorBody = Data(#"{"jsonrpc":"2.0","id":1,"error":{"code":-32602,"message":"Invalid params"}}"#.utf8)
            MockURLProtocol.handler = { _ in (200, errorBody, [:], nil) }

            let client = makeClient()
            do {
                _ = try await client.getAllBalances(owner: Self.walletAddress)
                #expect(Bool(false), "expected rpcError to throw")
            } catch let err as SuiRPCError {
                if case .rpcError(let code, let message) = err {
                    #expect(code == -32602)
                    #expect(message == "Invalid params")
                } else {
                    #expect(Bool(false), "wrong error case: \(err)")
                }
            }
        }
    }
}
