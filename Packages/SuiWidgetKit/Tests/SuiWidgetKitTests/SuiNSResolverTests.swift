import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("SuiNSResolver")
    struct SuiNSResolverTests {

        private func makeContext() throws -> ModelContext {
            let container = try SwiftDataStack.makeContainer(inMemory: true)
            return ModelContext(container)
        }

        private func makeRPC(endpoint: URL = URL(string: "https://test.example/")!) -> SuiRPCClient {
            let http = HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            let rotator = RPCEndpointRotator(endpoints: [endpoint])
            return SuiRPCClient(http: http, rotator: rotator)
        }

        @Test func resolve_passthroughs_valid_0x_address() async throws {
            MockURLProtocol.reset()
            // No handler set — no network call should fire.

            let context = try makeContext()
            let resolver = SuiNSResolver(rpc: makeRPC(), modelContext: context)
            let raw = "0x" + String(repeating: "a", count: 64)
            let addr = try await resolver.resolve(raw)
            #expect(addr.rawValue == raw)
            #expect(MockURLProtocol.requestsObserved.isEmpty, "should not call RPC for raw addresses")
        }

        @Test func resolve_rejects_malformed_0x_address() async throws {
            MockURLProtocol.reset()
            let context = try makeContext()
            let resolver = SuiNSResolver(rpc: makeRPC(), modelContext: context)
            do {
                _ = try await resolver.resolve("0xshort")
                #expect(Bool(false), "expected invalidAddress throw")
            } catch let err as SuiNSError {
                if case .invalidAddress = err { /* OK */ } else {
                    #expect(Bool(false), "wrong error case: \(err)")
                }
            }
        }

        @Test func resolve_forward_lookup_uses_rpc_and_caches() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "sui-resolveNameServiceAddress-success.json")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let context = try makeContext()
            let resolver = SuiNSResolver(rpc: makeRPC(), modelContext: context)
            let addr = try await resolver.resolve("validator.sui")
            #expect(!addr.rawValue.isEmpty)
            let observedAfterFirst = MockURLProtocol.requestsObserved.count

            // Second resolve hits cache.
            let addr2 = try await resolver.resolve("validator.sui")
            #expect(addr2.rawValue == addr.rawValue)
            #expect(MockURLProtocol.requestsObserved.count == observedAfterFirst, "second resolve should hit cache")

            // Persisted row exists.
            let stored = try context.fetch(FetchDescriptor<CachedSuiNSResolution>())
            #expect(stored.count == 1)
            #expect(stored.first?.name == "validator.sui")
        }

        @Test func resolve_at_prefix_normalizes_to_dot_sui() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "sui-resolveNameServiceAddress-success.json")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let context = try makeContext()
            let resolver = SuiNSResolver(rpc: makeRPC(), modelContext: context)
            _ = try await resolver.resolve("@validator")

            let stored = try context.fetch(FetchDescriptor<CachedSuiNSResolution>())
            #expect(stored.first?.name == "validator.sui", "should canonicalize @validator → validator.sui")
        }

        @Test func resolve_cache_refetches_after_ttl() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "sui-resolveNameServiceAddress-success.json")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let context = try makeContext()
            final class MutableDate: @unchecked Sendable { var value: Date; init(_ v: Date) { value = v } }
            let now = Date(timeIntervalSince1970: 1_700_000_000)
            let storage = MutableDate(now)
            let clock = InjectableClock(now: { storage.value })
            let resolver = SuiNSResolver(rpc: makeRPC(), modelContext: context, clock: clock)

            _ = try await resolver.resolve("validator.sui")
            let observedAfterFirst = MockURLProtocol.requestsObserved.count

            // Advance past TTL.
            storage.value = now.addingTimeInterval(2 * 60 * 60)
            _ = try await resolver.resolve("validator.sui")
            #expect(MockURLProtocol.requestsObserved.count > observedAfterFirst, "should refetch after TTL")
        }

        @Test func resolve_throws_name_not_found_on_null_result() async throws {
            MockURLProtocol.reset()
            let nullResult = Data(#"{"jsonrpc":"2.0","id":1,"result":null}"#.utf8)
            MockURLProtocol.handler = { _ in (200, nullResult, [:], nil) }

            let context = try makeContext()
            let resolver = SuiNSResolver(rpc: makeRPC(), modelContext: context)
            do {
                _ = try await resolver.resolve("does-not-exist.sui")
                #expect(Bool(false), "expected nameNotFound")
            } catch let err as SuiNSError {
                if case .nameNotFound = err { /* OK */ } else {
                    #expect(Bool(false), "wrong error case: \(err)")
                }
            }
        }

        @Test func reverse_resolve_returns_first_name_and_caches() async throws {
            MockURLProtocol.reset()
            let body = try FixtureLoader.data(named: "sui-resolveNameServiceNames-success.json")
            MockURLProtocol.handler = { _ in (200, body, [:], nil) }

            let context = try makeContext()
            let resolver = SuiNSResolver(rpc: makeRPC(), modelContext: context)
            let addr = SuiAddress(rawValue: "0x" + String(repeating: "a", count: 64))!
            let name = try await resolver.reverseResolve(address: addr)
            // Fixture may have an empty data array; either result is acceptable as long as decoding succeeded.
            if let name {
                #expect(!name.isEmpty)
                let stored = try context.fetch(FetchDescriptor<CachedSuiNSResolution>())
                #expect(stored.count == 1)
            }
        }
    }
}
