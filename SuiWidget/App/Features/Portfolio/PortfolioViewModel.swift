import Foundation
import SwiftData
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class PortfolioViewModel {
    var loadState: LoadState = .idle
    var wallets: [Wallet] = []
    var selectedWalletId: UUID?  // nil = "all wallets" aggregate (V1.1)
    var portfolio: CachedPortfolio?
    var stakeSummary: StakeSummary = .empty
    var refreshError: String?

    struct StakeSummary: Equatable {
        var totalUSD: Decimal
        var positionCount: Int
        var hasStakes: Bool { positionCount > 0 }
        static let empty = StakeSummary(totalUSD: 0, positionCount: 0)
    }

    private let modelContext: ModelContext
    private let walletService: WalletService
    private let portfolioService: PortfolioService
    private let stakingService: StakingService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        let suiNS = SuiNSResolver(rpc: rpc, modelContext: modelContext)
        self.walletService = WalletService(modelContext: modelContext, suiNS: suiNS)
        self.portfolioService = PortfolioService(
            modelContext: modelContext,
            sui: rpc,
            coinGecko: CoinGeckoClient(modelContext: modelContext)
        )
        self.stakingService = StakingService(modelContext: modelContext, sui: rpc)
    }

    func loadInitial() {
        do {
            wallets = try walletService.list()
            if selectedWalletId == nil {
                selectedWalletId = wallets.first(where: \.isPrimary)?.id ?? wallets.first?.id
            }
            loadCachedPortfolio()
            loadCachedStakes()
        } catch {
            loadState = .error(message: "Failed to load wallets: \(error.localizedDescription)", retry: nil)
        }
    }

    private func loadCachedPortfolio() {
        guard let walletId = selectedWalletId else {
            portfolio = nil
            loadState = .empty(message: "Add a wallet to start tracking your portfolio.")
            return
        }
        let id = walletId
        let descriptor = FetchDescriptor<CachedPortfolio>(
            predicate: #Predicate { $0.walletId == id }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            portfolio = cached
            loadState = .loaded
        } else {
            portfolio = nil
            loadState = .idle
        }
    }

    private func loadCachedStakes() {
        guard let walletId = selectedWalletId else {
            stakeSummary = .empty
            return
        }
        // Stakes are stored as children of CachedPortfolio; if no portfolio, no stakes.
        let id = walletId
        let descriptor = FetchDescriptor<CachedPortfolio>(predicate: #Predicate { $0.walletId == id })
        guard let portfolio = try? modelContext.fetch(descriptor).first else {
            stakeSummary = .empty
            return
        }
        let positions = portfolio.stakes
        let total = positions.reduce(Decimal(0)) { $0 + ($1.principal / Decimal(1_000_000_000)) }
        // principal is in SUI base units (9 decimals); we expose the SUI count here
        // (totalUSD field name is legacy — StakeSummary uses it as "total SUI" for V1).
        // A real USD valuation requires a live SUI price; the StakeListView hero card
        // shows the same SUI total.
        stakeSummary = StakeSummary(totalUSD: total, positionCount: positions.count)
    }

    func refresh() async {
        guard let walletId = selectedWalletId else { return }
        loadState = .loading
        refreshError = nil
        do {
            // Refresh portfolio + stakes in parallel.
            async let portfolioRefresh: Void = {
                _ = try await portfolioService.refresh(walletId: walletId)
            }()
            async let stakingRefresh: Void = {
                _ = try? await stakingService.refresh(walletId: walletId)
            }()
            _ = try await portfolioRefresh
            _ = await stakingRefresh
            loadCachedPortfolio()
            loadCachedStakes()
            loadState = .loaded
        } catch {
            // Show last cached + error pill.
            loadCachedPortfolio()
            if portfolio != nil {
                loadState = .error(message: "couldn't refresh — showing last cached", retry: nil)
            } else {
                loadState = .error(message: "couldn't load — \(error.localizedDescription)", retry: nil)
            }
            refreshError = error.localizedDescription
        }
    }

    func selectWallet(_ wallet: Wallet) {
        selectedWalletId = wallet.id
        loadCachedPortfolio()
        loadCachedStakes()
    }

    var selectedWallet: Wallet? {
        guard let id = selectedWalletId else { return nil }
        return wallets.first(where: { $0.id == id })
    }
}
