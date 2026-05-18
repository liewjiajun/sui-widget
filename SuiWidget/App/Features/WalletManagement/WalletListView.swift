import SwiftUI
import SwiftData
import SuiWidgetKit

struct WalletListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WalletListViewModel?
    @State private var showingAdd = false
    @State private var editTarget: Wallet?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear { viewModel = WalletListViewModel(modelContext: modelContext) }
            }
        }
        .navigationTitle("Wallets")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add wallet")
                }
            }
        }
        .sheet(isPresented: $showingAdd, onDismiss: { viewModel?.load() }) {
            NavigationStack {
                WalletAddView()
            }
        }
        .navigationDestination(item: $editTarget) { wallet in
            WalletEditView(wallet: wallet)
                .onDisappear { viewModel?.load() }
        }
    }

    @ViewBuilder
    private func content(viewModel: WalletListViewModel) -> some View {
        if viewModel.wallets.isEmpty {
            emptyState
        } else {
            List {
                if let primary = viewModel.primaryWallet {
                    Section("PRIMARY") {
                        Button(action: { editTarget = primary }) {
                            WalletRowView(wallet: primary, isPrimary: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !viewModel.otherWallets.isEmpty {
                    Section("OTHERS · \(viewModel.otherWallets.count)") {
                        ForEach(viewModel.otherWallets, id: \.id) { wallet in
                            Button(action: { editTarget = wallet }) {
                                WalletRowView(wallet: wallet, isPrimary: false)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.remove(wallet)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                Button {
                                    viewModel.setPrimary(wallet)
                                } label: {
                                    Label("Set primary", systemImage: "star")
                                }
                                .tint(SuiColor.suiBlue)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { viewModel.load() }
            .onAppear { viewModel.load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SuiSpacing.s4) {
            Spacer()
            SuiGlyph(size: 64)
            Text("No wallets yet")
                .font(SuiTypography.display(20))
            Text("Add a wallet to start tracking your portfolio.")
                .font(SuiTypography.body(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: { showingAdd = true }) {
                Label("Add wallet", systemImage: "plus")
                    .font(SuiTypography.body(15, weight: .semibold))
                    .padding(.horizontal, SuiSpacing.s4)
                    .padding(.vertical, SuiSpacing.s3)
                    .background(SuiColor.suiBlue, in: Capsule())
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }
}
