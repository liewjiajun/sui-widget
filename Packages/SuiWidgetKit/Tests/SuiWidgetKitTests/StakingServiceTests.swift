import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("StakingService")
    struct StakingServiceTests {

        // Matches the validator address used in `sui-getStakes-success.json`.
        // We use a custom-built system state response so the validator metadata
        // upsert path produces a row we can assert on.
        private static let stakesValidatorAddress =
            "0xb8068ad94d7f0448059ae3ea1d877f2af54792b2849d80e2753201adfa532411"

        private func makeContext() throws -> ModelContext {
            let container = try SwiftDataStack.makeContainer(inMemory: true)
            return ModelContext(container)
        }

        private func makeRPC(endpoint: URL = URL(string: "https://test.example/")!) -> SuiRPCClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            let rotator = RPCEndpointRotator(endpoints: [endpoint])
            return SuiRPCClient(http: http, rotator: rotator)
        }

        /// Builds a wallet + portfolio pair in the context. Returns the wallet id.
        private func seedWallet(_ context: ModelContext) throws -> UUID {
            let wallet = Wallet(
                address: "0x" + String(repeating: "a", count: 64),
                isPrimary: true,
                orderIndex: 0
            )
            context.insert(wallet)
            let portfolio = CachedPortfolio(walletId: wallet.id)
            context.insert(portfolio)
            try context.save()
            return wallet.id
        }

        /// Constructs a system-state JSON-RPC envelope with a single active
        /// validator whose `suiAddress` matches our stakes fixture.
        private func systemStateFixture() -> Data {
            let json = """
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "epoch": "1131",
                "activeValidators": [
                  {
                    "suiAddress": "\(Self.stakesValidatorAddress)",
                    "name": "Test Validator",
                    "imageUrl": "https://example.com/validator.png",
                    "description": "A test validator",
                    "commissionRate": "800",
                    "stakingPoolId": "0x1e4486bfe021b057d411e5c8916cbaf5e5fe60b758e05c045651a679de9cc9e9"
                  }
                ]
              }
            }
            """
            return Data(json.utf8)
        }

        /// Reads the JSON-RPC body — either from `httpBody` or by draining
        /// `httpBodyStream` — and returns the lowercased payload as text. Used to
        /// route stubbed responses by RPC method name.
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

        /// Stubs the stakes + system-state RPC responses. Counts each method's calls
        /// in the returned counters so tests can assert reuse-of-cache behaviour.
        private func setupHandler(
            stakes: Data,
            systemState: Data,
            stakesCount: MutableInt,
            systemStateCount: MutableInt
        ) {
            MockURLProtocol.handler = { request in
                let body = Self.decodeBody(request)
                if body.contains("suix_getStakes") {
                    stakesCount.increment()
                    return (200, stakes, [:], nil)
                }
                if body.contains("suix_getLatestSuiSystemState") {
                    systemStateCount.increment()
                    return (200, systemState, [:], nil)
                }
                return (404, Data(), [:], nil)
            }
        }

        @Test func refresh_populates_stake_rows_from_fixture() async throws {
            MockURLProtocol.reset()
            let stakes = try FixtureLoader.data(named: "sui-getStakes-success.json")
            let stakesCount = MutableInt()
            let systemStateCount = MutableInt()
            setupHandler(
                stakes: stakes,
                systemState: systemStateFixture(),
                stakesCount: stakesCount,
                systemStateCount: systemStateCount
            )

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = StakingService(modelContext: context, sui: makeRPC())

            let rows = try await service.refresh(walletId: walletId)
            #expect(!rows.isEmpty)
            #expect(rows.first?.validatorAddress == Self.stakesValidatorAddress)
            #expect((rows.first?.principal ?? 0) > Decimal(0))
        }

        @Test func refresh_caches_validator_metadata() async throws {
            MockURLProtocol.reset()
            let stakes = try FixtureLoader.data(named: "sui-getStakes-success.json")
            let stakesCount = MutableInt()
            let systemStateCount = MutableInt()
            setupHandler(
                stakes: stakes,
                systemState: systemStateFixture(),
                stakesCount: stakesCount,
                systemStateCount: systemStateCount
            )

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = StakingService(modelContext: context, sui: makeRPC())

            _ = try await service.refresh(walletId: walletId)
            let cached = try context.fetch(FetchDescriptor<CachedValidatorMetadata>())
            #expect(cached.count == 1)
            #expect(cached.first?.name == "Test Validator")
            #expect(cached.first?.validatorAddress == Self.stakesValidatorAddress)
        }

        @Test func refresh_reuses_validator_metadata_cache_within_ttl() async throws {
            MockURLProtocol.reset()
            let stakes = try FixtureLoader.data(named: "sui-getStakes-success.json")
            let stakesCount = MutableInt()
            let systemStateCount = MutableInt()
            setupHandler(
                stakes: stakes,
                systemState: systemStateFixture(),
                stakesCount: stakesCount,
                systemStateCount: systemStateCount
            )

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = StakingService(modelContext: context, sui: makeRPC())

            _ = try await service.refresh(walletId: walletId)
            let systemStateAfterFirst = systemStateCount.value

            _ = try await service.refresh(walletId: walletId)
            // Second refresh should NOT trigger another system state fetch.
            #expect(systemStateCount.value == systemStateAfterFirst)
        }

        @Test func refresh_refetches_validator_metadata_after_ttl() async throws {
            MockURLProtocol.reset()
            let stakes = try FixtureLoader.data(named: "sui-getStakes-success.json")
            let stakesCount = MutableInt()
            let systemStateCount = MutableInt()
            setupHandler(
                stakes: stakes,
                systemState: systemStateFixture(),
                stakesCount: stakesCount,
                systemStateCount: systemStateCount
            )

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let t0 = Date(timeIntervalSince1970: 1_700_000_000)
            let storage = MutableDateBox(t0)
            let clock = InjectableClock(now: { storage.value })
            let service = StakingService(modelContext: context, sui: makeRPC(), clock: clock)

            _ = try await service.refresh(walletId: walletId)
            let systemStateAfterFirst = systemStateCount.value

            // Advance past 6h TTL.
            storage.value = t0.addingTimeInterval(7 * 60 * 60)
            _ = try await service.refresh(walletId: walletId)
            #expect(systemStateCount.value > systemStateAfterFirst)
        }
    }
}

// MARK: - Test helpers

/// Threadsafe-enough counter. Tests are single-threaded so a class with mutable
/// var is plenty; @unchecked Sendable for closure capture in handler.
private final class MutableInt: @unchecked Sendable {
    private(set) var value: Int = 0
    func increment() { value += 1 }
}

private final class MutableDateBox: @unchecked Sendable {
    var value: Date
    init(_ v: Date) { value = v }
}
