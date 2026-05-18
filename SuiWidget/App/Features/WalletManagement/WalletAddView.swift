import SwiftUI
import SuiWidgetKit
import UIKit
import AVFoundation

struct WalletAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WalletAddViewModel?
    @State private var showingScanner = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        Group {
            if let viewModel {
                form(viewModel: viewModel)
                    .onChange(of: viewModel.didAdd) { _, didAdd in
                        if didAdd { dismiss() }
                    }
            } else {
                ProgressView()
                    .onAppear { viewModel = WalletAddViewModel(modelContext: modelContext) }
            }
        }
        .navigationTitle("Add wallet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showingScanner) {
            QRScannerView(
                onScan: { payload in
                    // Normalize: strip "sui:" prefix if present (some wallets emit URIs like sui:0x...)
                    var address = payload.trimmingCharacters(in: .whitespacesAndNewlines)
                    if address.lowercased().hasPrefix("sui:") {
                        address = String(address.dropFirst(4))
                    }
                    viewModel?.input = address
                    showingScanner = false
                },
                onCancel: { showingScanner = false }
            )
        }
    }

    @ViewBuilder
    private func form(viewModel: WalletAddViewModel) -> some View {
        Form {
            Section {
                TextField("0x… or name.sui or @name", text: Binding(
                    get: { viewModel.input },
                    set: { viewModel.input = $0 }
                ))
                .focused($inputFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(SuiTypography.mono(13))
                resolutionFeedback(viewModel.resolution)
            } header: {
                Text("Address or SuiNS name")
            } footer: {
                Text("Paste a 0x address, or type a .sui name to resolve.")
            }

            Section {
                HStack(spacing: SuiSpacing.s2) {
                    Button(action: pasteFromClipboard) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(SuiTypography.body(12, weight: .semibold))
                            .padding(.horizontal, SuiSpacing.s3)
                            .padding(.vertical, SuiSpacing.s2)
                            .background(Capsule().fill(SuiColor.suiBlue.opacity(0.12)))
                            .foregroundStyle(SuiColor.suiBlue)
                    }
                    .buttonStyle(.plain)
                    Button(action: { showingScanner = true }) {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                            .font(SuiTypography.body(12, weight: .semibold))
                            .padding(.horizontal, SuiSpacing.s3)
                            .padding(.vertical, SuiSpacing.s2)
                            .background(Capsule().fill(SuiColor.suiBlue.opacity(0.12)))
                            .foregroundStyle(SuiColor.suiBlue)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }

            Section("Options") {
                TextField("Label (optional)", text: Binding(
                    get: { viewModel.label },
                    set: { viewModel.label = $0 }
                ))
                Toggle("Set as primary", isOn: Binding(
                    get: { viewModel.setAsPrimary },
                    set: { viewModel.setAsPrimary = $0 }
                ))
            }

            if let error = viewModel.addError {
                Section {
                    Text(error).foregroundStyle(SuiColor.coral)
                }
            }

            Section {
                Button(action: { Task { await viewModel.add() } }) {
                    HStack {
                        Spacer()
                        Text("Add wallet")
                            .font(SuiTypography.body(15, weight: .semibold))
                        Spacer()
                    }
                }
                .disabled(!viewModel.canAdd)
                .listRowBackground(viewModel.canAdd ? SuiColor.suiBlue : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
            }
        }
        .onAppear { inputFocused = true }
    }

    private func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
            viewModel?.input = pasted
        }
    }

    @ViewBuilder
    private func resolutionFeedback(_ resolution: WalletAddResolution) -> some View {
        HStack(spacing: SuiSpacing.s2) {
            switch resolution {
            case .empty:
                EmptyView()
            case .resolving:
                ProgressView().controlSize(.small)
                Text("resolving…").font(SuiTypography.mono(11)).foregroundStyle(.secondary)
            case .resolved(let addr):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SuiColor.up)
                Text(WalletListViewModel.shortAddress(addr.rawValue))
                    .font(SuiTypography.mono(11))
                    .foregroundStyle(SuiColor.up)
            case .notFound:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(SuiColor.down)
                Text("not found").font(SuiTypography.mono(11)).foregroundStyle(SuiColor.down)
            case .invalid:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(SuiColor.coral)
                Text("invalid address").font(SuiTypography.mono(11)).foregroundStyle(SuiColor.coral)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(SuiColor.coral)
                Text(message).font(SuiTypography.mono(11)).foregroundStyle(SuiColor.coral).lineLimit(2)
            }
        }
        .frame(minHeight: 18)
    }
}
