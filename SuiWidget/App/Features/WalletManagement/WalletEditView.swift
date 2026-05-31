import SwiftUI
import SuiWidgetKit

struct WalletEditView: View {
    let wallet: Wallet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WalletEditViewModel?
    @State private var showRemoveConfirm = false

    var body: some View {
        Group {
            if let viewModel {
                form(viewModel: viewModel)
                    .onChange(of: viewModel.didDismiss) { _, dismiss in
                        if dismiss { self.dismiss() }
                    }
            } else {
                ProgressView()
                    .onAppear { viewModel = WalletEditViewModel(wallet: wallet, modelContext: modelContext) }
            }
        }
        .navigationTitle(WalletListViewModel.displayLabel(for: wallet))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func form(viewModel: WalletEditViewModel) -> some View {
        Form {
            Section("Identity") {
                LabeledContent("Address") {
                    Text(WalletListViewModel.shortAddress(wallet.address))
                        .font(SuiTypography.mono(11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                TextField("Label", text: Binding(
                    get: { viewModel.label },
                    set: { viewModel.label = $0 }
                ))
                if let suiName = wallet.suiNSName, !suiName.isEmpty {
                    LabeledContent("SuiNS") {
                        Text(suiName).font(SuiTypography.mono(11)).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Options") {
                Toggle("Primary wallet", isOn: Binding(
                    get: { viewModel.isPrimary },
                    set: { viewModel.isPrimary = $0 }
                ))
                Toggle("Include in widget", isOn: Binding(
                    get: { viewModel.includeInWidget },
                    set: { viewModel.includeInWidget = $0 }
                ))
            }

            if let error = viewModel.saveError {
                Section {
                    Text(error).foregroundStyle(SuiColor.coral)
                }
            }

            Section {
                Button("Save changes") { viewModel.save() }
                    .font(SuiTypography.body(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }

            Section {
                Button("Remove wallet", role: .destructive) { showRemoveConfirm = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog(
            "Remove this wallet?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { viewModel.remove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removing the primary wallet promotes another wallet to primary.")
        }
    }
}
