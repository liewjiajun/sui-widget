import SwiftUI
import SwiftData
import SuiWidgetKit

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PortfolioViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
                    .refreshable { await viewModel.refresh() }
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = PortfolioViewModel(modelContext: modelContext)
                        viewModel?.loadInitial()
                    }
            }
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let viewModel, !viewModel.wallets.isEmpty {
                    walletPicker(viewModel: viewModel)
                }
            }
        }
    }

    @ViewBuilder
    private func walletPicker(viewModel: PortfolioViewModel) -> some View {
        Menu {
            ForEach(viewModel.wallets, id: \.id) { wallet in
                Button(action: { viewModel.selectWallet(wallet) }) {
                    Label(WalletListViewModel.displayLabel(for: wallet),
                          systemImage: wallet.id == viewModel.selectedWalletId ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(viewModel.selectedWallet.map(WalletListViewModel.displayLabel) ?? "all")
                    .font(SuiTypography.body(13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(SuiTypography.body(10))
            }
            .padding(.horizontal, SuiSpacing.s2)
            .padding(.vertical, SuiSpacing.s1)
            .background(Capsule().fill(SuiColor.suiBlue.opacity(0.12)))
            .foregroundStyle(SuiColor.suiBlue)
        }
    }

    @ViewBuilder
    private func content(viewModel: PortfolioViewModel) -> some View {
        switch viewModel.loadState {
        case .empty:
            emptyState
        case .loading where viewModel.portfolio == nil:
            ProgressView("Syncing…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            ScrollView {
                VStack(spacing: SuiSpacing.s4) {
                    if let portfolio = viewModel.portfolio {
                        donutSection(portfolio: portfolio)
                        if viewModel.stakeSummary.hasStakes {
                            NavigationLink {
                                StakeListView(walletId: portfolio.walletId)
                            } label: {
                                StakedBadgeView(summary: viewModel.stakeSummary)
                            }
                            .buttonStyle(.plain)
                        }
                        tokenSection(portfolio: portfolio)
                    } else {
                        firstSyncPrompt(viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
    }

    private func donutSection(portfolio: CachedPortfolio) -> some View {
        let slices = PortfolioDonutView.slices(from: portfolio)
        return VStack(spacing: SuiSpacing.s3) {
            HStack(alignment: .top, spacing: SuiSpacing.s4) {
                PortfolioDonutView(slices: slices, totalUSD: portfolio.totalUSD)
                VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                    ForEach(slices.prefix(4)) { slice in
                        HStack(spacing: SuiSpacing.s2) {
                            Circle().fill(slice.color).frame(width: 8, height: 8)
                            Text(slice.label).font(SuiTypography.body(12, weight: .semibold))
                            Spacer()
                            Text(percentLabel(slice.value, total: portfolio.totalUSD))
                                .font(SuiTypography.mono(11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            // 24h delta below donut+legend.
            HStack(spacing: SuiSpacing.s2) {
                let isUp = portfolio.change24hUSD >= 0
                Text(isUp ? "▲" : "▼")
                    .foregroundStyle(isUp ? SuiColor.up : SuiColor.down)
                Text(String(format: "%.2f%%", abs(portfolio.change24hPercent)))
                    .font(SuiTypography.display(14))
                    .foregroundStyle(isUp ? SuiColor.up : SuiColor.down)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(usdDelta(portfolio.change24hUSD))
                    .font(SuiTypography.mono(12, weight: .medium))
                    .foregroundStyle(isUp ? SuiColor.up : SuiColor.down)
                Spacer()
                Text("24h").font(SuiTypography.mono(10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, SuiSpacing.s2)
        }
    }

    @ViewBuilder
    private func tokenSection(portfolio: CachedPortfolio) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("TOKENS · \(portfolio.tokens.count)")
                .font(SuiTypography.mono(10, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                let slices = PortfolioDonutView.slices(from: portfolio)
                let colorByCoinType: [String: Color] = Dictionary(
                    uniqueKeysWithValues: portfolio.tokens.filter(\.isTracked).enumerated().compactMap { idx, h in
                        guard let slice = slices.first(where: { $0.label == h.symbol }) else {
                            return nil
                        }
                        _ = idx
                        return (h.coinType, slice.color)
                    }
                )
                let sortedTokens = portfolio.tokens.sorted { tokenSortValue($0) > tokenSortValue($1) }
                ForEach(sortedTokens, id: \.id) { holding in
                    NavigationLink {
                        TokenDetailView(holding: holding)
                    } label: {
                        TokenRowView(holding: holding, sliceColor: colorByCoinType[holding.coinType])
                    }
                    .buttonStyle(.plain)
                    if holding.id != sortedTokens.last?.id {
                        Divider()
                    }
                }
            }
            .padding(SuiSpacing.s2)
            .background(
                RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func tokenSortValue(_ holding: CachedTokenHolding) -> Decimal {
        (holding.priceUSD ?? 0) * holding.balance
    }

    private func firstSyncPrompt(viewModel: PortfolioViewModel) -> some View {
        VStack(spacing: SuiSpacing.s4) {
            SuiGlyph(size: 64)
            Text("Pull to refresh, or:")
                .font(SuiTypography.body(13))
                .foregroundStyle(.secondary)
            Button(action: { Task { await viewModel.refresh() } }) {
                Label("Refresh now", systemImage: "arrow.clockwise")
                    .font(SuiTypography.body(15, weight: .semibold))
                    .padding(.horizontal, SuiSpacing.s4)
                    .padding(.vertical, SuiSpacing.s2)
                    .background(SuiColor.suiBlue, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: SuiSpacing.s4) {
            Spacer()
            SuiGlyph(size: 64)
            Text("No wallets yet")
                .font(SuiTypography.display(20))
            Text("Add a wallet from Settings → Wallets to start tracking your portfolio.")
                .font(SuiTypography.body(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private func percentLabel(_ value: Decimal, total: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let pct = (value / total) * 100
        return String(format: "%.0f%%", NSDecimalNumber(decimal: pct).doubleValue)
    }

    private func usdDelta(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.positivePrefix = "+$"
        formatter.negativePrefix = "−$"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}
