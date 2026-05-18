import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("NFTService")
    struct NFTServiceTests {

        /// The `nextCursor` value embedded in `sui-getOwnedObjects-page1.json`.
        /// When the service paginates with this cursor we return a synthetic
        /// empty page so the loop terminates without needing a second fixture.
        private static let page1NextCursor =
            "0x1336e43b0fa22cd066b567816a8789a0198959de9eb8760c4003f3f9e4d3bc24"

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

        /// Reads the JSON-RPC body — either from `httpBody` or via a streaming
        /// drain of `httpBodyStream` — and returns the payload text. Some
        /// URLSession configurations strip `httpBody` once the request reaches
        /// the protocol, so the stream path is required.
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

        /// Stubs `suix_getOwnedObjects`. Page 1 (no cursor in params) returns the
        /// recorded fixture; when the service re-requests with the cursor from
        /// page 1, we synthesize an empty terminal page.
        private func setupPaginationHandler(callCount: MutableInt) throws {
            let page1 = try FixtureLoader.data(named: "sui-getOwnedObjects-page1.json")
            let terminalPage = Data(#"{"jsonrpc":"2.0","id":1,"result":{"data":[],"nextCursor":null,"hasNextPage":false}}"#.utf8)
            MockURLProtocol.handler = { request in
                callCount.increment()
                let body = Self.decodeBody(request)
                if body.contains(Self.page1NextCursor) {
                    return (200, terminalPage, [:], nil)
                }
                return (200, page1, [:], nil)
            }
        }

        @Test func refresh_populates_nft_rows_from_fixture() async throws {
            MockURLProtocol.reset()
            let count = MutableInt()
            try setupPaginationHandler(callCount: count)

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = NFTService(modelContext: context, sui: makeRPC())

            let result = try await service.refresh(walletId: walletId)
            #expect(!result.isEmpty)
            // Only display-bearing objects are returned; the fixture has several
            // SuiNS registrations and whitelist allowlists that qualify.
            #expect(result.contains(where: { $0.name.hasSuffix(".sui") }))
        }

        @Test func refresh_upserts_by_objectId() async throws {
            MockURLProtocol.reset()
            let count = MutableInt()
            try setupPaginationHandler(callCount: count)

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = NFTService(modelContext: context, sui: makeRPC())

            _ = try await service.refresh(walletId: walletId)
            let firstCount = try context.fetch(FetchDescriptor<CachedNFTItem>()).count

            _ = try await service.refresh(walletId: walletId)
            let secondCount = try context.fetch(FetchDescriptor<CachedNFTItem>()).count
            #expect(firstCount == secondCount, "second refresh should upsert, not duplicate")
        }

        @Test func refresh_paginates_until_hasNextPage_false() async throws {
            MockURLProtocol.reset()
            let count = MutableInt()
            try setupPaginationHandler(callCount: count)

            let context = try makeContext()
            let walletId = try seedWallet(context)
            let service = NFTService(modelContext: context, sui: makeRPC())

            _ = try await service.refresh(walletId: walletId)
            // First call returns page1 (hasNextPage=true), second returns the
            // synthetic terminal page (hasNextPage=false). Exactly two calls.
            #expect(count.value == 2)
        }
    }
}

private final class MutableInt: @unchecked Sendable {
    private(set) var value: Int = 0
    func increment() { value += 1 }
}
