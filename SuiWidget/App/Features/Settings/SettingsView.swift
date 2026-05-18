import SwiftUI
import SwiftData
import SuiWidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var showingResetConfirmation = false
    @AppStorage("preferredColorScheme") private var preferredColorSchemeRaw: String = AppTheme.system.rawValue

    var body: some View {
        Group {
            if let viewModel {
                form(viewModel: viewModel)
                    .onChange(of: viewModel.theme) { _, newTheme in
                        preferredColorSchemeRaw = newTheme.rawValue
                        viewModel.save()
                    }
                    .onChange(of: viewModel.defaultCurrency) { _, _ in viewModel.save() }
                    .onChange(of: viewModel.showUntrackedTokens) { _, _ in viewModel.save() }
                    .onChange(of: viewModel.refreshFrequency) { _, _ in viewModel.save() }
                    .onChange(of: viewModel.notificationsEnabled) { _, _ in viewModel.save() }
            } else {
                ProgressView()
                    .onAppear { viewModel = SettingsViewModel(modelContext: modelContext) }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func form(viewModel: SettingsViewModel) -> some View {
        Form {
            Section("Account") {
                NavigationLink {
                    WalletListView()
                } label: {
                    Label("Wallets", systemImage: "wallet.pass")
                }
            }

            Section("Widgets") {
                NavigationLink {
                    WidgetConfigView()
                } label: {
                    Label("Widget configurator", systemImage: "rectangle.3.group")
                }
            }

            Section("DISPLAY") {
                Picker("Theme", selection: Binding(
                    get: { viewModel.theme },
                    set: { viewModel.theme = $0 }
                )) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                Picker("Default currency", selection: Binding(
                    get: { viewModel.defaultCurrency },
                    set: { viewModel.defaultCurrency = $0 }
                )) {
                    ForEach(DefaultCurrency.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                Toggle("Show untracked tokens", isOn: Binding(
                    get: { viewModel.showUntrackedTokens },
                    set: { viewModel.showUntrackedTokens = $0 }
                ))
            }

            Section("DATA") {
                Picker("Refresh frequency", selection: Binding(
                    get: { viewModel.refreshFrequency },
                    set: { viewModel.refreshFrequency = $0 }
                )) {
                    ForEach(AppRefreshFrequency.allCases) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                Toggle("Notifications", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.notificationsEnabled = $0 }
                ))
                Button(action: viewModel.clearCache) {
                    HStack {
                        Label("Clear cache", systemImage: "trash")
                        Spacer()
                        if viewModel.clearedCacheConfirmation {
                            Label("Cleared", systemImage: "checkmark")
                                .foregroundStyle(SuiColor.up)
                                .font(SuiTypography.mono(11, weight: .bold))
                        } else {
                            Text("~\(viewModel.cacheBytesLabel)")
                                .font(SuiTypography.mono(11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }

            Section("ABOUT") {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About & credits", systemImage: "info.circle")
                }
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Reset everything", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Reset everything?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset everything", role: .destructive) {
                Task { await viewModel.resetEverything() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes all cached data, wallets, settings, and re-runs onboarding next launch.")
        }
    }
}

private struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                SuiGlyph(size: 96)
                Text("Sui Widget")
                    .font(SuiTypography.display(28))
                Text("V1 · A community tool")
                    .font(SuiTypography.body(14))
                    .foregroundStyle(.secondary)
                Text("Free, read-only iOS app for tracking your Sui portfolio, NFTs, staking and ecosystem news on Home and Lock screens.")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("Not an official Sui Foundation app.")
                    .font(SuiTypography.mono(11))
                    .foregroundStyle(.secondary)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
