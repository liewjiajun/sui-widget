import Foundation
import SwiftData

/// Fetches a wallet's delegated stakes and enriches each position with cached
/// validator metadata. The validator metadata cache has a 6-hour TTL: if all
/// touched validators are fresh, the system state RPC is skipped on subsequent
/// refreshes.
public struct StakingService {
    public let modelContext: ModelContext
    public let sui: SuiRPCClient
    public let validatorMetadataTTL: TimeInterval
    public let clock: InjectableClock

    public init(
        modelContext: ModelContext,
        sui: SuiRPCClient = SuiRPCClient(),
        validatorMetadataTTL: TimeInterval = 6 * 60 * 60,  // 6 hours
        clock: InjectableClock = .system
    ) {
        self.modelContext = modelContext
        self.sui = sui
        self.validatorMetadataTTL = validatorMetadataTTL
        self.clock = clock
    }

    /// Refreshes stake positions for a wallet. Fetches getStakes, enriches each
    /// position with validator metadata (cached 6h), persists flat CachedStakePosition rows.
    @discardableResult
    public func refresh(walletId: UUID) async throws -> [CachedStakePosition] {
        let wallet = try fetchWallet(id: walletId)
        guard let owner = SuiAddress(rawValue: wallet.address) else {
            throw SuiNSError.invalidAddress(wallet.address)
        }

        let stakes = try await sui.getStakes(owner: owner)

        // Refresh validator metadata for any uncached / stale validators.
        let validatorAddresses = Set(stakes.map(\.validatorAddress))
        try await refreshValidatorMetadataIfNeeded(addresses: validatorAddresses)

        // Build CachedStakePosition rows.
        let metadataByAddress = try fetchValidatorMetadataByAddress()
        var newRows: [CachedStakePosition] = []
        for stake in stakes {
            let meta = metadataByAddress[stake.validatorAddress]
            for entry in stake.stakes {
                newRows.append(CachedStakePosition(
                    validatorAddress: stake.validatorAddress,
                    validatorName: meta?.name,
                    validatorImageURL: meta?.imageURL,
                    principal: entry.principal,
                    estimatedReward: entry.estimatedReward ?? 0,
                    status: StakingService.mapStatus(entry.status),
                    stakingPool: stake.stakingPool
                ))
            }
        }

        // Replace existing stake rows on the wallet's portfolio. Cascade rule
        // on `CachedPortfolio.stakes` deletes orphans, but SwiftData can flag
        // "missing delete propagation" if we mutate the relationship while
        // iterating its current contents — so we drop the relationship
        // wholesale and then explicitly delete the orphaned rows, mirroring
        // the safer set-diff pattern used by NFTService.
        if let portfolio = try fetchPortfolio(walletId: walletId) {
            let oldStakes = portfolio.stakes
            for row in newRows { modelContext.insert(row) }
            portfolio.stakes = newRows
            for old in oldStakes {
                modelContext.delete(old)
            }
        }

        try modelContext.save()
        return newRows
    }

    // MARK: - Helpers

    private func refreshValidatorMetadataIfNeeded(addresses: Set<String>) async throws {
        let now = clock.now()
        let metadataByAddress = try fetchValidatorMetadataByAddress()
        let stale = addresses.filter { addr in
            guard let cached = metadataByAddress[addr] else { return true }
            return now.timeIntervalSince(cached.cachedAt) >= validatorMetadataTTL
        }
        if stale.isEmpty { return }

        // One system state fetch covers all validators we care about.
        let state = try await sui.getLatestSuiSystemState()
        let validatorsByAddress: [String: SuiValidatorInfo] = Dictionary(
            uniqueKeysWithValues: state.activeValidators.map { ($0.suiAddress, $0) }
        )

        for addr in stale {
            guard let info = validatorsByAddress[addr] else { continue }
            let commissionRate = Double(info.commissionRate) ?? 0
            if let existing = metadataByAddress[addr] {
                existing.name = info.name
                existing.imageURL = info.imageUrl
                existing.validatorDescription = info.description
                existing.commissionRate = commissionRate
                existing.stakingPool = info.stakingPoolId
                existing.cachedAt = now
            } else {
                modelContext.insert(CachedValidatorMetadata(
                    validatorAddress: addr,
                    name: info.name,
                    imageURL: info.imageUrl,
                    validatorDescription: info.description,
                    commissionRate: commissionRate,
                    stakingPool: info.stakingPoolId,
                    cachedAt: now
                ))
            }
        }
    }

    private static func mapStatus(_ raw: String) -> StakeStatus {
        // Sui RPC returns "Active", "Pending", "Unstaked" (PascalCase).
        switch raw.lowercased() {
        case "active": return .active
        case "pending": return .pending
        case "unstaked", "withdrawing": return .withdrawing
        default: return .pending
        }
    }

    private func fetchWallet(id: UUID) throws -> Wallet {
        var descriptor = FetchDescriptor<Wallet>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let wallet = try modelContext.fetch(descriptor).first else {
            throw NSError(
                domain: "StakingService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Wallet not found"]
            )
        }
        return wallet
    }

    private func fetchValidatorMetadataByAddress() throws -> [String: CachedValidatorMetadata] {
        let rows = try modelContext.fetch(FetchDescriptor<CachedValidatorMetadata>())
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.validatorAddress, $0) })
    }

    private func fetchPortfolio(walletId: UUID) throws -> CachedPortfolio? {
        var descriptor = FetchDescriptor<CachedPortfolio>(predicate: #Predicate { $0.walletId == walletId })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
