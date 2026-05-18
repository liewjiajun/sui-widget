import Foundation
import SwiftData
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class WalletEditViewModel {
    let walletId: UUID
    var label: String
    var isPrimary: Bool
    var includeInWidget: Bool
    var saveError: String?
    var didDismiss: Bool = false

    private let modelContext: ModelContext
    private let walletService: WalletService

    init(wallet: Wallet, modelContext: ModelContext) {
        self.walletId = wallet.id
        self.label = wallet.label ?? ""
        self.isPrimary = wallet.isPrimary
        self.includeInWidget = true  // For V1 there's no per-wallet widget include flag on the model; assumed true.
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        let suiNS = SuiNSResolver(rpc: rpc, modelContext: modelContext)
        self.walletService = WalletService(modelContext: modelContext, suiNS: suiNS)
    }

    func save() {
        do {
            let wallets = try walletService.list()
            guard let wallet = wallets.first(where: { $0.id == walletId }) else {
                saveError = "Wallet no longer exists"
                return
            }
            wallet.label = label.isEmpty ? nil : label
            try modelContext.save()
            if isPrimary {
                try walletService.setPrimary(id: walletId)
            }
            didDismiss = true
            saveError = nil
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    func remove() {
        do {
            try walletService.remove(id: walletId)
            didDismiss = true
            saveError = nil
        } catch {
            saveError = "Failed to remove: \(error.localizedDescription)"
        }
    }
}
