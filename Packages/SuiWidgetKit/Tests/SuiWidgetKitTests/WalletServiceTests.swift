import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

@Suite("WalletService")
struct WalletServiceTests {

    private func makeContext() throws -> ModelContext {
        let container = try SwiftDataStack.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    private func makeService(_ context: ModelContext) -> WalletService {
        let rpc = SuiRPCClient(
            http: HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 }),
            rotator: RPCEndpointRotator(endpoints: [URL(string: "https://test.example/")!])
        )
        let suiNS = SuiNSResolver(rpc: rpc, modelContext: context)
        return WalletService(modelContext: context, suiNS: suiNS)
    }

    @Test func add_with_0x_address_persists_wallet_as_primary() async throws {
        let context = try makeContext()
        let service = makeService(context)
        let raw = "0x" + String(repeating: "a", count: 64)
        let wallet = try await service.add(addressOrName: raw, label: "Main")
        #expect(wallet.address == raw)
        #expect(wallet.label == "Main")
        #expect(wallet.isPrimary == true)
        #expect(wallet.orderIndex == 0)
    }

    @Test func add_second_wallet_is_not_primary() async throws {
        let context = try makeContext()
        let service = makeService(context)
        _ = try await service.add(addressOrName: "0x" + String(repeating: "a", count: 64))
        let second = try await service.add(addressOrName: "0x" + String(repeating: "b", count: 64))
        #expect(second.isPrimary == false)
        #expect(second.orderIndex == 1)
    }

    @Test func list_returns_wallets_in_order_index() async throws {
        let context = try makeContext()
        let service = makeService(context)
        _ = try await service.add(addressOrName: "0x" + String(repeating: "a", count: 64))
        _ = try await service.add(addressOrName: "0x" + String(repeating: "b", count: 64))
        let listed = try service.list()
        #expect(listed.count == 2)
        #expect(listed[0].orderIndex == 0)
        #expect(listed[1].orderIndex == 1)
    }

    @Test func remove_primary_promotes_next_wallet() async throws {
        let context = try makeContext()
        let service = makeService(context)
        let first = try await service.add(addressOrName: "0x" + String(repeating: "a", count: 64))
        _ = try await service.add(addressOrName: "0x" + String(repeating: "b", count: 64))

        try service.remove(id: first.id)
        let remaining = try service.list()
        #expect(remaining.count == 1)
        #expect(remaining[0].isPrimary == true)
    }

    @Test func setPrimary_toggles_correctly() async throws {
        let context = try makeContext()
        let service = makeService(context)
        _ = try await service.add(addressOrName: "0x" + String(repeating: "a", count: 64))
        let second = try await service.add(addressOrName: "0x" + String(repeating: "b", count: 64))

        try service.setPrimary(id: second.id)
        let listed = try service.list()
        #expect(listed.first(where: { $0.isPrimary })?.id == second.id)
    }
}
