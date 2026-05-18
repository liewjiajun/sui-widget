import Foundation
import SwiftData

/// CRUD for the user's tracked wallets. Resolves SuiNS inputs on insertion and
/// keeps a single `isPrimary` invariant: removing the primary promotes the next
/// wallet in `orderIndex`.
public struct WalletService {
    public let modelContext: ModelContext
    public let suiNS: SuiNSResolver

    public init(modelContext: ModelContext, suiNS: SuiNSResolver) {
        self.modelContext = modelContext
        self.suiNS = suiNS
    }

    /// Adds a wallet. Accepts `0x...`, `name.sui`, or `@name`.
    /// Resolves the name through SuiNS. The first wallet inserted is marked primary.
    @discardableResult
    public func add(
        addressOrName input: String,
        label: String? = nil,
        includeInWidget: Bool = true
    ) async throws -> Wallet {
        let address = try await suiNS.resolve(input)
        let existing = try list()
        let isFirst = existing.isEmpty
        // If the user typed a name (.sui or @prefix) store it as-is. Otherwise
        // they pasted a 0x address — do a best-effort reverse SuiNS lookup so
        // the widget's "SuiNS name" display option has something to show. The
        // reverse-resolve is best-effort; wallet-add still succeeds if it fails.
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let suiNSName: String?
        if trimmedInput.hasSuffix(".sui") || trimmedInput.hasPrefix("@") {
            suiNSName = trimmedInput.lowercased()
        } else {
            suiNSName = try? await suiNS.reverseResolve(address: address)
        }
        let wallet = Wallet(
            address: address.rawValue,
            label: label,
            suiNSName: suiNSName,
            isPrimary: isFirst,
            orderIndex: existing.count,
            includeInWidget: includeInWidget
        )
        modelContext.insert(wallet)
        try modelContext.save()
        return wallet
    }

    /// Lists all wallets ordered by `orderIndex` ascending.
    public func list() throws -> [Wallet] {
        let descriptor = FetchDescriptor<Wallet>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Removes the wallet by id; promotes the next wallet (by orderIndex) to primary
    /// if the removed wallet was primary.
    public func remove(id: UUID) throws {
        let descriptor = FetchDescriptor<Wallet>(predicate: #Predicate { $0.id == id })
        guard let wallet = try modelContext.fetch(descriptor).first else { return }
        let wasPrimary = wallet.isPrimary
        modelContext.delete(wallet)
        try modelContext.save()
        // Promote first remaining wallet if we just removed the primary.
        if wasPrimary {
            let remaining = try list()
            if let nextPrimary = remaining.first {
                nextPrimary.isPrimary = true
                try modelContext.save()
            }
        }
    }

    /// Switches the primary wallet to the given id. Other wallets become non-primary.
    public func setPrimary(id: UUID) throws {
        let all = try list()
        for wallet in all {
            wallet.isPrimary = (wallet.id == id)
        }
        try modelContext.save()
    }
}
