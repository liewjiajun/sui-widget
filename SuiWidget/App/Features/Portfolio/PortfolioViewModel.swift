import Foundation
import SwiftData
import Observation
import SuiWidgetKit
import WidgetKit

@MainActor
@Observable
final class PortfolioViewModel {
    var loadState: LoadState = .idle
    var wallets: [Wallet] = []
    /// nil = "all wallets" aggregate mode. Selecting an individual wallet
    /// populates `portfolio`; selecting nil populates `aggregate` instead.
    var selectedWalletId: UUID?
    var portfolio: CachedPortfolio?
    var aggregate: AggregateView?
    var stakeSummary: StakeSummary = .empty
    var refreshError: String?

    struct StakeSummary: Equatable {
        var totalUSD: Decimal
        var positionCount: Int
        var hasStakes: Bool { positionCount > 0 }
        static let empty = StakeSummary(totalUSD: 0, positionCount: 0)
    }

    /// Display-only aggregate across all wallets. The token holdings inside are
    /// freshly constructed `CachedTokenHolding` instances (not inserted into
    /// the ModelContext); each one represents the merged-balance view of a
    /// canonicalized coin type across every wallet.
    struct AggregateView {
        let totalUSD: Decimal
        let change24hUSD: Decimal
        let change24hPercent: Double
        let tokens: [CachedTokenHolding]
        let stakes: [CachedStakePosition]
        let walletCount: Int
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
            if selectedWalletId == nil {
                loadCachedAggregate()
                loadAggregateStakes()
            } else {
                loadCachedPortfolio()
                loadCachedStakes()
            }
        } catch {
            loadState = .error(message: "Failed to load wallets: \(error.localizedDescription)", retry: nil)
        }
    }

    private func loadCachedPortfolio() {
        aggregate = nil
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

    // MARK: - Aggregate ("All wallets") mode

    func selectAggregate() {
        selectedWalletId = nil
        loadCachedAggregate()
        loadAggregateStakes()
    }

    private func loadCachedAggregate() {
        let allDescriptor = FetchDescriptor<CachedPortfolio>()
        let allPortfolios = (try? modelContext.fetch(allDescriptor)) ?? []
        guard !allPortfolios.isEmpty else {
            aggregate = nil
            portfolio = nil
            loadState = .empty(message: wallets.isEmpty
                ? "Add a wallet to start tracking your portfolio."
                : "Pull-to-refresh to populate aggregate data.")
            return
        }
        portfolio = nil

        // Merge token holdings by canonical coin type.
        var mergedByCoinType: [String: (holding: CachedTokenHolding, balance: Decimal)] = [:]
        var totalUSD = Decimal(0)
        var totalChangeUSD = Decimal(0)

        for p in allPortfolios {
            totalUSD += p.totalUSD
            totalChangeUSD += p.change24hUSD
            for token in p.tokens {
                let key = CoinTypeCanonicalizer.canonicalize(token.coinType)
                if let existing = mergedByCoinType[key] {
                    mergedByCoinType[key] = (existing.holding, existing.balance + token.balance)
                } else {
                    mergedByCoinType[key] = (token, token.balance)
                }
            }
        }

        // Build display-only CachedTokenHolding instances (not inserted into the
        // ModelContext — SwiftData @Model instances are usable as plain Swift
        // objects for read-only display.)
        let mergedTokens: [CachedTokenHolding] = mergedByCoinType.values.map { entry in
            CachedTokenHolding(
                coinType: entry.holding.coinType,
                symbol: entry.holding.symbol,
                name: entry.holding.name,
                balance: entry.balance,
                decimals: entry.holding.decimals,
                priceUSD: entry.holding.priceUSD,
                priceChange24h: entry.holding.priceChange24h,
                iconURL: entry.holding.iconURL,
                isTracked: entry.holding.isTracked
            )
        }

        let mergedStakes = allPortfolios.flatMap(\.stakes)

        let changePercent: Double = {
            let yesterdayUSD = totalUSD - totalChangeUSD
            guard yesterdayUSD > 0 else { return 0 }
            let ratio = (totalChangeUSD / yesterdayUSD) as NSDecimalNumber
            return ratio.doubleValue * 100
        }()

        aggregate = AggregateView(
            totalUSD: totalUSD,
            change24hUSD: totalChangeUSD,
            change24hPercent: changePercent,
            tokens: mergedTokens,
            stakes: mergedStakes,
            walletCount: allPortfolios.count
        )
        loadState = .loaded
    }

    private func loadAggregateStakes() {
        guard let agg = aggregate else { stakeSummary = .empty; return }
        let positions = agg.stakes
        let total = positions.reduce(Decimal(0)) { $0 + ($1.principal / Decimal(1_000_000_000)) }
        stakeSummary = StakeSummary(totalUSD: total, positionCount: positions.count)
    }

    func refresh() async {
        loadState = .loading
        refreshError = nil
        if let walletId = selectedWalletId {
            await refreshSingleWallet(walletId: walletId)
        } else {
            await refreshAllWallets()
        }
    }

    private func refreshSingleWallet(walletId: UUID) async {
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
            // Tell the widget extension the shared SwiftData store has fresh
            // data so its next timeline render reflects the user-visible refresh.
            WidgetCenter.shared.reloadAllTimelines()
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

    private func refreshAllWallets() async {
        var lastError: Error?
        for wallet in wallets {
            do {
                _ = try await portfolioService.refresh(walletId: wallet.id)
            } catch {
                lastError = error
            }
            _ = try? await stakingService.refresh(walletId: wallet.id)
        }
        loadCachedAggregate()
        loadAggregateStakes()
        WidgetCenter.shared.reloadAllTimelines()
        if let lastError {
            refreshError = lastError.localizedDescription
            if aggregate != nil {
                loadState = .error(message: "couldn't refresh some wallets — showing last cached", retry: nil)
            } else {
                loadState = .error(message: "couldn't load — \(lastError.localizedDescription)", retry: nil)
            }
        } else {
            loadState = .loaded
        }
    }

    func selectWallet(_ wallet: Wallet) {
        selectedWalletId = wallet.id
        aggregate = nil
        loadCachedPortfolio()
        loadCachedStakes()
    }

    var selectedWallet: Wallet? {
        guard let id = selectedWalletId else { return nil }
        return wallets.first(where: { $0.id == id })
    }
}
