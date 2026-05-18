import SwiftUI
import SwiftData
import SuiWidgetKit
import UIKit

/// Onboarding page 3 (Add wallet). Reuses WalletAddViewModel from Task 3 for SuiNS resolution.
struct OnboardingAddWalletView: View {
    let onComplete: () -> Void
    let onSkip: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WalletAddViewModel?
    @State private var showingScanner = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
                    .onChange(of: viewModel.didAdd) { _, didAdd in
                        if didAdd { onComplete() }
                    }
            } else {
                ProgressView()
                    .onAppear { viewModel = WalletAddViewModel(modelContext: modelContext) }
            }
        }
        .sheet(isPresented: $showingScanner) {
            QRScannerView(
                onScan: { payload in
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
    private func content(viewModel: WalletAddViewModel) -> some View {
        VStack(spacing: SuiSpacing.s4) {
            Spacer().frame(height: SuiSpacing.s5)

            VStack(spacing: SuiSpacing.s2) {
                Text("Add your first wallet")
                    .font(SuiTypography.display(28))
                Text("Paste a 0x address or type a .sui name.")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                TextField("0x… or name.sui", text: Binding(
                    get: { viewModel.input },
                    set: { viewModel.input = $0 }
                ))
                .focused($inputFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(SuiSpacing.s3)
                .font(SuiTypography.mono(13))
                .background(
                    RoundedRectangle(cornerRadius: SuiSpacing.inputRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                resolutionFeedback(viewModel.resolution)
                    .padding(.horizontal, SuiSpacing.s2)
            }
            .padding(.horizontal)

            // Paste + Scan QR pills
            HStack(spacing: SuiSpacing.s2) {
                Button(action: pasteFromClipboard) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(SuiTypography.body(12, weight: .semibold))
                        .padding(.horizontal, SuiSpacing.s3)
                        .padding(.vertical, SuiSpacing.s2)
                        .background(Capsule().fill(SuiColor.suiBlue.opacity(0.12)))
                        .foregroundStyle(SuiColor.suiBlue)
                }
                Button(action: { showingScanner = true }) {
                    Label("Scan QR", systemImage: "qrcode.viewfinder")
                        .font(SuiTypography.body(12, weight: .semibold))
                        .padding(.horizontal, SuiSpacing.s3)
                        .padding(.vertical, SuiSpacing.s2)
                        .background(Capsule().fill(SuiColor.suiBlue.opacity(0.12)))
                        .foregroundStyle(SuiColor.suiBlue)
                }
                Spacer()
            }
            .padding(.horizontal)

            TextField("Label (optional)", text: Binding(
                get: { viewModel.label },
                set: { viewModel.label = $0 }
            ))
            .padding(SuiSpacing.s3)
            .background(
                RoundedRectangle(cornerRadius: SuiSpacing.inputRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal)

            if let error = viewModel.addError {
                Text(error).foregroundStyle(SuiColor.coral).font(SuiTypography.body(12)).padding(.horizontal)
            }

            Spacer()

            VStack(spacing: SuiSpacing.s2) {
                Button(action: { Task { await viewModel.add() } }) {
                    Label("Finish & install widget", systemImage: "arrow.right")
                        .font(SuiTypography.body(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SuiSpacing.s3)
                        .background(viewModel.canAdd ? SuiColor.suiBlue : SuiColor.flat.opacity(0.3), in: Capsule())
                        .foregroundStyle(.white)
                }
                .disabled(!viewModel.canAdd)
                Button("Skip for now", action: onSkip)
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SuiSpacing.s5)
            .padding(.bottom, 80)
        }
        .padding()
        .onAppear { inputFocused = true }
    }

    private func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.string {
            viewModel?.input = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    @ViewBuilder
    private func resolutionFeedback(_ resolution: WalletAddResolution) -> some View {
        HStack(spacing: SuiSpacing.s2) {
            switch resolution {
            case .empty: EmptyView()
            case .resolving:
                ProgressView().controlSize(.small)
                Text("resolving…").font(SuiTypography.mono(11)).foregroundStyle(.secondary)
            case .resolved(let addr):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(SuiColor.up)
                Text(WalletListViewModel.shortAddress(addr.rawValue))
                    .font(SuiTypography.mono(11))
                    .foregroundStyle(SuiColor.up)
            case .notFound:
                Image(systemName: "xmark.circle.fill").foregroundStyle(SuiColor.down)
                Text("not found").font(SuiTypography.mono(11)).foregroundStyle(SuiColor.down)
            case .invalid:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SuiColor.coral)
                Text("invalid address").font(SuiTypography.mono(11)).foregroundStyle(SuiColor.coral)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SuiColor.coral)
                Text(message).font(SuiTypography.mono(11)).foregroundStyle(SuiColor.coral).lineLimit(2)
            }
        }
        .frame(minHeight: 18)
    }
}
