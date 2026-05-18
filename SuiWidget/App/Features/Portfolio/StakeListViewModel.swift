import Foundation
import SwiftData
import Observation
import SuiWidgetKit
import WidgetKit

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
            // Widgets pull from the same shared store; reload after a successful
            // refresh so they pick up the new stake data on next render.
            WidgetCenter.shared.reloadAllTimelines()
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

    /// Network-base APY estimate for V1. Sui's epoch-wise reward distribution
    /// makes this a moving target; the figure comes from the validator
    /// commission set (which we already cache) by computing
    /// `(1 - meanCommission) * 5.0%` — a defensible V1 approximation pending a
    /// future suix_getStakeRewardsRate RPC integration.
    ///
    /// Per position: `effectiveAPY = networkBaseAPY * (1 - commissionFraction)`
    /// where `commissionFraction = commissionRate / 10_000` (Sui basis points).
    /// Returns the principal-weighted mean across `positions`, or nil if there
    /// are no positions / zero principal.
    var weightedAverageAPY: Double? {
        guard !positions.isEmpty else { return nil }

        // Fetch all cached validator metadata once and index by address.
        let descriptor = FetchDescriptor<CachedValidatorMetadata>()
        let validators = (try? modelContext.fetch(descriptor)) ?? []
        let validatorByAddress: [String: CachedValidatorMetadata] = Dictionary(
            uniqueKeysWithValues: validators.map { ($0.validatorAddress, $0) }
        )

        // Network-level base APY for V1 (Sui mainnet hovers around 4.5–5.5% net
        // of commission across the active set).
        let networkBaseAPY: Double = 5.0

        let totalPrincipal = positions.reduce(Decimal(0)) { $0 + $1.principal }
        guard totalPrincipal > 0 else { return nil }
        let totalPrincipalDouble = (totalPrincipal as NSDecimalNumber).doubleValue
        guard totalPrincipalDouble > 0 else { return nil }

        var weightedSum: Double = 0
        for position in positions {
            let validator = validatorByAddress[position.validatorAddress]
            // commissionRate is stored as basis points (0–10000 per Sui
            // convention). Clamp to [0, 1] after dividing to guard against
            // out-of-range cached values.
            let commission = validator?.commissionRate ?? 0
            let commissionFraction = max(0, min(1, commission / 10_000))
            let effectiveAPY = networkBaseAPY * (1 - commissionFraction)

            let principalShare = (position.principal as NSDecimalNumber).doubleValue
                                / totalPrincipalDouble
            weightedSum += effectiveAPY * principalShare
        }
        return weightedSum
    }
}
