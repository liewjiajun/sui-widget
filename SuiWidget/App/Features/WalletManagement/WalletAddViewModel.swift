import Foundation
import SwiftData
import Observation
import SuiWidgetKit

enum WalletAddResolution: Equatable {
    case empty
    case resolving
    case resolved(SuiAddress)
    case notFound
    case invalid
    case error(String)
}

@MainActor
@Observable
final class WalletAddViewModel {
    var input: String = "" {
        didSet {
            guard input != oldValue else { return }
            scheduleResolution()
        }
    }
    var label: String = ""
    var setAsPrimary: Bool = false
    var resolution: WalletAddResolution = .empty
    var didAdd: Bool = false
    var addError: String?

    private let modelContext: ModelContext
    private let walletService: WalletService
    private let suiNS: SuiNSResolver
    private var resolveTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        let resolver = SuiNSResolver(rpc: rpc, modelContext: modelContext)
        self.suiNS = resolver
        self.walletService = WalletService(modelContext: modelContext, suiNS: resolver)
    }

    private func scheduleResolution() {
        resolveTask?.cancel()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            resolution = .empty
            return
        }
        // Plain 0x address validates immediately, no debounce.
        if trimmed.hasPrefix("0x") {
            if let addr = SuiAddress(rawValue: trimmed) {
                resolution = .resolved(addr)
            } else {
                resolution = .invalid
            }
            return
        }
        // .sui or @name — debounce 400ms then RPC.
        resolution = .resolving
        resolveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.resolveInput(trimmed)
        }
    }

    private func resolveInput(_ trimmed: String) async {
        do {
            let addr = try await suiNS.resolve(trimmed)
            resolution = .resolved(addr)
        } catch let err as SuiNSError {
            switch err {
            case .nameNotFound: resolution = .notFound
            case .invalidName, .invalidAddress: resolution = .invalid
            case .rpc(let underlying): resolution = .error(underlying.localizedDescription)
            }
        } catch {
            resolution = .error(error.localizedDescription)
        }
    }

    var canAdd: Bool {
        if case .resolved = resolution { return true }
        return false
    }

    func add() async {
        guard canAdd else { return }
        do {
            let wallet = try await walletService.add(
                addressOrName: input.trimmingCharacters(in: .whitespacesAndNewlines),
                label: label.isEmpty ? nil : label
            )
            if setAsPrimary { try walletService.setPrimary(id: wallet.id) }
            didAdd = true
            addError = nil
        } catch {
            addError = "Failed to add wallet: \(error.localizedDescription)"
        }
    }
}
