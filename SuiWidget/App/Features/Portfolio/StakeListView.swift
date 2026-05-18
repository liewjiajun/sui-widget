import SwiftUI
import SwiftData
import SuiWidgetKit

struct StakeListView: View {
    let walletId: UUID
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: StakeListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
                    .refreshable { await viewModel.refresh() }
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = StakeListViewModel(walletId: walletId, modelContext: modelContext)
                        viewModel?.load()
                    }
            }
        }
        .navigationTitle("Stakes")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func content(viewModel: StakeListViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuiSpacing.s4) {
                heroCard(viewModel: viewModel)
                positionsSection(viewModel: viewModel)
            }
            .padding()
        }
    }

    private func heroCard(viewModel: StakeListViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("STAKED · \(viewModel.positions.count) " + (viewModel.positions.count == 1 ? "POSITION" : "POSITIONS"))
                .font(SuiTypography.mono(10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(suiAmountLabel(viewModel.totalStakedSUI))
                .font(SuiTypography.pixelDisplay(36))
                .contentTransition(.numericText())
            HStack(spacing: SuiSpacing.s2) {
                if viewModel.totalEstimatedRewardSUI > 0 {
                    Text("+\(suiAmountLabel(viewModel.totalEstimatedRewardSUI)) est. reward")
                        .font(SuiTypography.mono(11, weight: .bold))
                        .foregroundStyle(SuiColor.up)
                }
                if let apy = viewModel.weightedAverageAPY {
                    Text("·").foregroundStyle(.secondary)
                    Text(String(format: "%.1f%% avg APY", apy))
                        .font(SuiTypography.mono(11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(SuiColor.up.opacity(0.10))
        )
    }

    @ViewBuilder
    private func positionsSection(viewModel: StakeListViewModel) -> some View {
        if case .empty(let message) = viewModel.loadState {
            VStack(spacing: SuiSpacing.s3) {
                Spacer().frame(height: SuiSpacing.s5)
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } else {
            Text("POSITIONS")
                .font(SuiTypography.mono(10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, SuiSpacing.s2)
            VStack(spacing: SuiSpacing.s2) {
                ForEach(viewModel.positions, id: \.id) { position in
                    NavigationLink {
                        ValidatorDetailView(position: position)
                    } label: {
                        StakeRowView(position: position)
                    }
                    .buttonStyle(.plain)
                }
            }
            if case .error(let message, _) = viewModel.loadState {
                HStack(spacing: SuiSpacing.s1) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message)
                }
                .font(SuiTypography.mono(11))
                .foregroundStyle(SuiColor.coral)
                .padding(.top, SuiSpacing.s2)
            }
        }
    }

    private func suiAmountLabel(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        let str = f.string(from: value as NSDecimalNumber) ?? "0"
        return "\(str) SUI"
    }
}
