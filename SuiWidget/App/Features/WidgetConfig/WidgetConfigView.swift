import SwiftUI
import SuiWidgetKit

struct WidgetConfigView: View {
    @State private var viewModel = WidgetConfigViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuiSpacing.s4) {
                WidgetPreviewCard(family: viewModel.selectedFamily, intent: viewModel.previewIntent)
                familyPicker
                drillRows
            }
            .padding()
        }
        .navigationTitle("Configure widget")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var familyPicker: some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("WIDGET").font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SuiSpacing.s2) {
                    ForEach(WidgetFamilyOption.allCases) { family in
                        Button(action: { viewModel.selectedFamily = family }) {
                            VStack(spacing: 4) {
                                Image(systemName: family.iconSystemName)
                                    .font(.system(size: 22))
                                    .frame(width: 36, height: 36)
                                Text(family.displayName)
                                    .font(SuiTypography.mono(9, weight: .bold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, SuiSpacing.s2)
                            .padding(.vertical, SuiSpacing.s2)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(viewModel.selectedFamily == family ? SuiColor.suiBlue.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(viewModel.selectedFamily == family ? SuiColor.suiBlue : Color.clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(viewModel.selectedFamily == family ? SuiColor.suiBlue : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var drillRows: some View {
        VStack(spacing: SuiSpacing.s2) {
            settingRow(label: "Wallets", value: viewModel.walletScope == .all ? "All wallets" : "Primary wallet") {
                Picker("Wallet scope", selection: Binding(get: { viewModel.walletScope }, set: { viewModel.walletScope = $0 })) {
                    Text("Primary wallet").tag(WalletScopeOption.primary)
                    Text("All wallets").tag(WalletScopeOption.all)
                }
                .pickerStyle(.inline)
            }
            settingRow(label: "Refresh frequency", value: refreshLabel) {
                Picker("Refresh", selection: Binding(get: { viewModel.refresh }, set: { viewModel.refresh = $0 })) {
                    Text("Auto").tag(RefreshFrequencyOption.auto)
                    Text("Every 15 minutes").tag(RefreshFrequencyOption.fifteenMinutes)
                    Text("Every 30 minutes").tag(RefreshFrequencyOption.thirtyMinutes)
                    Text("Every hour").tag(RefreshFrequencyOption.hourly)
                }
                .pickerStyle(.inline)
            }
            settingRow(label: "Currency", value: viewModel.currency.rawValue.uppercased()) {
                Picker("Currency", selection: Binding(get: { viewModel.currency }, set: { viewModel.currency = $0 })) {
                    ForEach(CurrencyOption.allCases, id: \.self) { c in
                        Text(c.rawValue.uppercased()).tag(c)
                    }
                }
                .pickerStyle(.inline)
            }
            settingRow(label: "Show wallet as", value: walletDisplayLabel) {
                Picker("Show wallet as", selection: Binding(get: { viewModel.walletDisplay }, set: { viewModel.walletDisplay = $0 })) {
                    ForEach(WalletIdentifierDisplayOption.allCases, id: \.self) { option in
                        Text(walletDisplayShortLabel(option)).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            footerNote
        }
    }

    private var walletDisplayLabel: String {
        walletDisplayShortLabel(viewModel.walletDisplay)
    }

    private func walletDisplayShortLabel(_ option: WalletIdentifierDisplayOption) -> String {
        switch option {
        case .suiNSName: return "SuiNS name"
        case .atName: return "@ name"
        case .address: return "Address"
        case .hidden: return "Hidden"
        }
    }

    private var refreshLabel: String {
        switch viewModel.refresh {
        case .auto: return "Auto"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .hourly: return "Hourly"
        }
    }

    @ViewBuilder
    private func settingRow<Picker: View>(label: String, value: String, @ViewBuilder picker: @escaping () -> Picker) -> some View {
        DisclosureGroup {
            picker()
                .padding(.top, SuiSpacing.s2)
        } label: {
            HStack {
                Text(label).font(SuiTypography.body(14, weight: .medium))
                Spacer()
                Text(value).font(SuiTypography.mono(11)).foregroundStyle(.secondary)
            }
        }
        .padding(SuiSpacing.s3)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s1) {
            Text("How to apply")
                .font(SuiTypography.mono(9, weight: .bold))
                .foregroundStyle(.secondary)
            Text("This preview shows what each widget variant looks like. To configure a specific widget on your Home or Lock Screen, long-press the widget and tap \"Edit Widget\".")
                .font(SuiTypography.body(11))
                .foregroundStyle(.secondary)
        }
        .padding(SuiSpacing.s3)
    }
}
