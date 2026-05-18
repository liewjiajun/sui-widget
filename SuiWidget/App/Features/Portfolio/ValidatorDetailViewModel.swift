import Foundation
import SwiftData
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class ValidatorDetailViewModel {
    let position: CachedStakePosition
    var validator: CachedValidatorMetadata?

    private let modelContext: ModelContext

    init(position: CachedStakePosition, modelContext: ModelContext) {
        self.position = position
        self.modelContext = modelContext
    }

    func load() {
        let address = position.validatorAddress
        let descriptor = FetchDescriptor<CachedValidatorMetadata>(
            predicate: #Predicate { $0.validatorAddress == address }
        )
        validator = try? modelContext.fetch(descriptor).first
    }

    /// Commission rate displayed as a percent. Sui stores commissionRate as basis
    /// points (0–10_000); divide by 100 to get a 0–100 percent figure.
    var commissionRatePercent: Double {
        guard let validator else { return 0 }
        return validator.commissionRate / 100  // basis points → percent (1000 bp = 10%)
    }

    /// Effective APY mirrors StakeListViewModel.weightedAverageAPY logic for a
    /// single position: `networkBaseAPY * (1 - commissionFraction)`.
    var effectiveAPYPercent: Double {
        let networkBaseAPY = 5.0
        let commissionFraction = max(0, min(1, (validator?.commissionRate ?? 0) / 10_000))
        return networkBaseAPY * (1 - commissionFraction)
    }

    var principalSUI: Decimal { position.principal / Decimal(1_000_000_000) }
    var rewardSUI: Decimal { position.estimatedReward / Decimal(1_000_000_000) }
}
