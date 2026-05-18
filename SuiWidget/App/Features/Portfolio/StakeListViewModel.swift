import Foundation
import SwiftData
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class StakeListViewModel {
    let walletId: UUID
    var loadState: LoadState = .idle
    var positions: [CachedStakePosition] = []
    var refreshError: String?

    private let modelContext: ModelContext
    private let stakingService: StakingService

    init(walletId: UUID, modelContext: ModelContext) {
        self.walletId = walletId
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        self.stakingService = StakingService(modelContext: modelContext, sui: rpc)
    }

    func load() {
        let id = walletId
        let descriptor = FetchDescriptor<CachedPortfolio>(
            predicate: #Predicate { $0.walletId == id }
        )
        if let portfolio = try? modelContext.fetch(descriptor).first {
            positions = portfolio.stakes
            loadState = positions.isEmpty
                ? .empty(message: "No stake positions for this wallet yet.")
                : .loaded
        } else {
            positions = []
            loadState = .empty(message: "No portfolio cached yet — pull to refresh.")
        }
    }

    func refresh() async {
        loadState = .loading
        do {
            _ = try await stakingService.refresh(walletId: walletId)
            load()
        } catch {
            refreshError = error.localizedDescription
            loadState = positions.isEmpty
                ? .error(message: "couldn't load: \(error.localizedDescription)", retry: nil)
                : .error(message: "couldn't refresh — showing last cached", retry: nil)
        }
    }

    // Aggregate hero values.
    var totalStakedSUI: Decimal {
        positions.reduce(Decimal(0)) { $0 + ($1.principal / Decimal(1_000_000_000)) }
    }

    var totalEstimatedRewardSUI: Decimal {
        positions.reduce(Decimal(0)) { $0 + ($1.estimatedReward / Decimal(1_000_000_000)) }
    }

    /// Average APY weighted by principal. Returns nil if no positions or no validator metadata.
    var weightedAverageAPY: Double? {
        // We don't have explicit APY on CachedStakePosition; estimate as
        // (estimatedReward / principal) for the position's lifetime, then weight.
        // For V1 this is a placeholder display — real per-validator APY comes from the
        // CachedValidatorMetadata.commissionRate + system state in V1.1.
        guard !positions.isEmpty else { return nil }
        let avgRewardRate = positions.compactMap { pos -> Double? in
            guard pos.principal > 0 else { return nil }
            let ratio = (pos.estimatedReward as NSDecimalNumber).doubleValue
                       / (pos.principal as NSDecimalNumber).doubleValue
            return ratio * 100
        }.reduce(0, +) / Double(positions.count)
        return avgRewardRate
    }
}
