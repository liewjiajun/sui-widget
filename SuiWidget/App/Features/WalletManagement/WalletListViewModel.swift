import Foundation
import SwiftData
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class WalletListViewModel {
    var wallets: [Wallet] = []
    var loadError: String?

    private let modelContext: ModelContext
    private let walletService: WalletService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        let suiNS = SuiNSResolver(rpc: rpc, modelContext: modelContext)
        self.walletService = WalletService(modelContext: modelContext, suiNS: suiNS)
    }

    func load() {
        do {
            wallets = try walletService.list()
            loadError = nil
        } catch {
            loadError = "Failed to load wallets: \(error.localizedDescription)"
        }
    }

    func remove(_ wallet: Wallet) {
        do {
            try walletService.remove(id: wallet.id)
            load()
        } catch {
            loadError = "Failed to remove wallet: \(error.localizedDescription)"
        }
    }

    func setPrimary(_ wallet: Wallet) {
        do {
            try walletService.setPrimary(id: wallet.id)
            load()
        } catch {
            loadError = "Failed to set primary: \(error.localizedDescription)"
        }
    }

    /// Aggregates: total + per-wallet for use in the list footer.
    var primaryWallet: Wallet? { wallets.first(where: \.isPrimary) }
    var otherWallets: [Wallet] { wallets.filter { !$0.isPrimary } }

    /// Short display: SuiNS name if available, else truncated address.
    static func displayLabel(for wallet: Wallet) -> String {
        if let name = wallet.suiNSName, !name.isEmpty { return name }
        if let label = wallet.label, !label.isEmpty { return label }
        return shortAddress(wallet.address)
    }

    static func shortAddress(_ address: String) -> String {
        let trimmed = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        guard trimmed.count > 8 else { return address }
        let head = trimmed.prefix(4)
        let tail = trimmed.suffix(4)
        return "0x\(head)…\(tail)"
    }
}
