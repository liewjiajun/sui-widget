import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

/// Live network integration tests against the chosen public mainnet wallet.
/// Disabled by default — these tests hit real APIs and are slow/flaky in CI.
///
/// Run manually:
///   swift test --package-path Packages/SuiWidgetKit --filter "Live integration"
///
/// Test wallet: 0xe6d2886da571e044dd3873d40eba75aa5610c51618f0c48fa0ca376d492d56a8
/// (validator.sui / doonie.sui) — chosen during Phase 1 Task 7 fixture recording.
@Suite("Live integration", .disabled("hits real APIs; enable manually via --filter"))
struct LiveIntegrationTests {

    static let testWalletAddress = "0xe6d2886da571e044dd3873d40eba75aa5610c51618f0c48fa0ca376d492d56a8"

    @Test("PortfolioService.refresh against mainnet returns non-empty portfolio")
    func portfolioRefresh_forKnownMainnetWallet() async throws {
        guard let address = SuiAddress(rawValue: Self.testWalletAddress) else {
            Issue.record("Hard-coded test wallet failed SuiAddress validation")
            return
        }

        let container = try SwiftDataStack.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let walletId = UUID()
        let wallet = Wallet(
            id: walletId,
            address: address.rawValue,
            label: "Integration test",
            isPrimary: true,
            orderIndex: 0
        )
        context.insert(wallet)
        try context.save()

        let service = PortfolioService(
            modelContext: context,
            sui: SuiRPCClient(),
            coinGecko: CoinGeckoClient(modelContext: context)
        )
        let portfolio = try await service.refresh(walletId: walletId)

        #expect(!portfolio.tokens.isEmpty, "wallet should have at least one token balance")
        print("LIVE PORTFOLIO — wallet \(address): \(portfolio.tokens.count) tokens, total USD ~\(portfolio.totalUSD)")
        for token in portfolio.tokens.prefix(5) {
            print("  \(token.symbol) (\(token.coinType.prefix(40))…): balance=\(token.balance), tracked=\(token.isTracked), priceUSD=\(token.priceUSD ?? 0)")
        }
    }

    @Test("StakingService.refresh against mainnet returns non-empty stakes")
    func stakingRefresh_forKnownMainnetWallet() async throws {
        guard let address = SuiAddress(rawValue: Self.testWalletAddress) else { return }

        let container = try SwiftDataStack.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let walletId = UUID()
        let wallet = Wallet(id: walletId, address: address.rawValue, isPrimary: true)
        context.insert(wallet)
        // Insert a CachedPortfolio so StakingService has a parent to attach to.
        context.insert(CachedPortfolio(walletId: walletId))
        try context.save()

        let service = StakingService(modelContext: context, sui: SuiRPCClient())
        let stakes = try await service.refresh(walletId: walletId)
        print("LIVE STAKES — wallet \(address): \(stakes.count) positions")
        for stake in stakes.prefix(3) {
            print("  \(stake.validatorName ?? stake.validatorAddress.prefix(12).description): principal=\(stake.principal), status=\(stake.status.rawValue)")
        }
        #expect(!stakes.isEmpty, "test wallet was chosen to have at least one active stake")
    }

    @Test("NewsService.refresh against live feeds returns non-empty results")
    func newsRefresh_fromLiveFeeds() async throws {
        let container = try SwiftDataStack.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let service = NewsService(modelContext: context)
        let items = try await service.refresh(force: true)
        #expect(!items.isEmpty, "live RSS feeds should return at least one item")
        print("LIVE NEWS — \(items.count) items, latest: \(items.first?.title ?? "(none)")")
    }

    @Test("SuiNSResolver against mainnet resolves a known .sui name")
    func suiNSResolver_resolves_validator_sui() async throws {
        let container = try SwiftDataStack.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let resolver = SuiNSResolver(rpc: SuiRPCClient(), modelContext: context)
        let address = try await resolver.resolve("validator.sui")
        print("LIVE SUINS — validator.sui → \(address)")
        #expect(address.rawValue.hasPrefix("0x"))
    }
}
