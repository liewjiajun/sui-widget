import SwiftUI
import SwiftData
import Charts
import SuiWidgetKit

struct TokenDetailView: View {
    let holding: CachedTokenHolding
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TokenDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
                    .task { await viewModel.load() }
            } else {
                ProgressView()
                    .onAppear { viewModel = TokenDetailViewModel(holding: holding, modelContext: modelContext) }
            }
        }
        .navigationTitle(holding.symbol)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(viewModel: TokenDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                heroValueCard(viewModel: viewModel)
                chartCard(viewModel: viewModel)
                statsCard(viewModel: viewModel)
                metadataCard
            }
            .padding()
        }
    }

    private func heroValueCard(viewModel: TokenDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("YOUR HOLDING").font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
            Text(formattedBalance)
                .font(SuiTypography.display(28))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if holding.isTracked {
                Text(formattedUSDValue(viewModel.holdingValueUSD))
                    .font(SuiTypography.display(18))
                    .foregroundStyle(.secondary)
            } else {
                Text("Untracked — not listed on CoinGecko")
                    .font(SuiTypography.mono(10, weight: .bold))
                    .foregroundStyle(SuiColor.flat)
            }
            if let priceUSD = holding.priceUSD {
                HStack(spacing: SuiSpacing.s2) {
                    Text("Price").font(SuiTypography.mono(10, weight: .bold)).foregroundStyle(.secondary)
                    Text(formattedUSDValue(priceUSD))
                        .font(SuiTypography.display(14))
                    if let change = holding.priceChange24h {
                        HStack(spacing: 2) {
                            Text(change >= 0 ? "▲" : "▼")
                            Text(String(format: "%.1f%%", abs(change)))
                        }
                        .font(SuiTypography.mono(11, weight: .bold))
                        .foregroundStyle(change >= 0 ? SuiColor.up : SuiColor.down)
                    }
                }
            }
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func chartCard(viewModel: TokenDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            HStack {
                Text("7-DAY PRICE").font(SuiTypography.mono(10, weight: .bold)).foregroundStyle(.secondary)
                Spacer()
                if let sevenDayChange = viewModel.sevenDayChange {
                    HStack(spacing: 2) {
                        Text(sevenDayChange >= 0 ? "▲" : "▼")
                        Text(String(format: "%.1f%%", abs(sevenDayChange)))
                    }
                    .font(SuiTypography.mono(11, weight: .bold))
                    .foregroundStyle(sevenDayChange >= 0 ? SuiColor.up : SuiColor.down)
                }
            }
            switch viewModel.loadState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, minHeight: 160)
            case .loaded:
                Chart {
                    ForEach(viewModel.pricePoints, id: \.timestamp) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Price USD", (point.price as NSDecimalNumber).doubleValue)
                        )
                        .foregroundStyle(SuiColor.suiBlue)
                        .interpolationMethod(.linear)
                    }
                }
                .frame(height: 160)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(SuiColor.flat.opacity(0.3))
                        AxisValueLabel()
                            .font(SuiTypography.mono(9))
                            .foregroundStyle(.secondary)
                    }
                }
            case .empty(let message):
                Text(message)
                    .font(SuiTypography.body(12))
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 160)
            case .error(let message, _):
                Text(message)
                    .font(SuiTypography.body(12))
                    .foregroundStyle(SuiColor.coral)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 160)
            default:
                EmptyView()
            }
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func statsCard(viewModel: TokenDetailViewModel) -> some View {
        if !viewModel.pricePoints.isEmpty {
            VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                Text("7-DAY STATS").font(SuiTypography.mono(10, weight: .bold)).foregroundStyle(.secondary)
                HStack {
                    statBlock(label: "Min", value: formattedUSDValue(viewModel.minPrice))
                    Divider().frame(height: 32)
                    statBlock(label: "Max", value: formattedUSDValue(viewModel.maxPrice))
                    if holding.isTracked, let price = holding.priceUSD {
                        Divider().frame(height: 32)
                        statBlock(label: "Now", value: formattedUSDValue(price))
                    }
                }
            }
            .padding(SuiSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
            Text(value).font(SuiTypography.display(13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("METADATA").font(SuiTypography.mono(10, weight: .bold)).foregroundStyle(.secondary)
            HStack(alignment: .top) {
                Text("Name").font(SuiTypography.body(12, weight: .semibold))
                Spacer()
                Text(holding.name).font(SuiTypography.body(12)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            HStack(alignment: .top) {
                Text("Coin type").font(SuiTypography.body(12, weight: .semibold))
                Spacer()
                Text(holding.coinType).font(SuiTypography.mono(10)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.trailing).textSelection(.enabled)
            }
            HStack(alignment: .top) {
                Text("Decimals").font(SuiTypography.body(12, weight: .semibold))
                Spacer()
                Text("\(holding.decimals)").font(SuiTypography.mono(12)).foregroundStyle(.secondary)
            }
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var formattedBalance: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        let amount = f.string(from: holding.balance as NSDecimalNumber) ?? "0"
        return "\(amount) \(holding.symbol)"
    }

    private func formattedUSDValue(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = value > 1 ? 2 : 6
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
