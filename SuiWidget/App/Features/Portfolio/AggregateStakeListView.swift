import SwiftUI
import SwiftData
import Observation
import WidgetKit
import SuiWidgetKit

/// Stake list for "all wallets" aggregate mode. Shows a hero summarising the
/// total staked SUI + estimated reward across every wallet, then a per-wallet
/// section so the user can see which validator each position lives under and
/// drill into a single wallet's stake list with one tap.
struct AggregateStakeListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: AggregateStakeListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
                    .refreshable { await viewModel.refresh() }
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = AggregateStakeListViewModel(modelContext: modelContext)
                        viewModel?.load()
                    }
            }
        }
        .navigationTitle("Stakes (all wallets)")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func content(viewModel: AggregateStakeListViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuiSpacing.s4) {
                heroCard(viewModel: viewModel)
                if viewModel.walletGroups.isEmpty {
                    emptyState
                } else {
                    walletSections(viewModel: viewModel)
                }
            }
            .padding()
        }
    }

    private func heroCard(viewModel: AggregateStakeListViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("STAKED · \(viewModel.walletGroups.count) " +
                 (viewModel.walletGroups.count == 1 ? "WALLET" : "WALLETS") +
                 " · \(viewModel.totalPositionCount) " +
                 (viewModel.totalPositionCount == 1 ? "POSITION" : "POSITIONS"))
                .font(SuiTypography.mono(10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(suiAmountLabel(viewModel.totalStakedSUI))
                .font(SuiTypography.pixelDisplay(36))
                .contentTransition(.numericText())
            if viewModel.totalEstimatedRewardSUI > 0 {
                Text("+\(suiAmountLabel(viewModel.totalEstimatedRewardSUI)) est. reward")
                    .font(SuiTypography.mono(11, weight: .bold))
                    .foregroundStyle(SuiColor.up)
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
    private func walletSections(viewModel: AggregateStakeListViewModel) -> some View {
        ForEach(viewModel.walletGroups) { group in
            VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                HStack {
                    Text(group.walletDisplay.uppercased())
                        .font(SuiTypography.mono(10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    NavigationLink {
                        StakeListView(walletId: group.walletId)
                    } label: {
                        HStack(spacing: 2) {
                            Text("VIEW WALLET")
                                .font(SuiTypography.mono(9, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(SuiColor.suiBlue)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: SuiSpacing.s2) {
                    ForEach(group.positions, id: \.id) { position in
                        StakeRowView(position: position)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SuiSpacing.s3) {
            Spacer().frame(height: SuiSpacing.s5)
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No stake positions yet across your wallets.")
                .font(SuiTypography.body(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func suiAmountLabel(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        let str = f.string(from: value as NSDecimalNumber) ?? "0"
        return "\(str) SUI"
    }
}

@MainActor
@Observable
final class AggregateStakeListViewModel {
    struct WalletStakes: Identifiable {
        let walletId: UUID
        let walletDisplay: String
        let positions: [CachedStakePosition]
        var id: UUID { walletId }
    }

    var walletGroups: [WalletStakes] = []
    var totalStakedSUI: Decimal = 0
    var totalEstimatedRewardSUI: Decimal = 0
    var totalPositionCount: Int = 0

    private let modelContext: ModelContext
    private let stakingService: StakingService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.stakingService = StakingService(modelContext: modelContext, sui: SuiRPCClient())
    }

    func load() {
        let portfolios = (try? modelContext.fetch(FetchDescriptor<CachedPortfolio>())) ?? []
        let wallets = (try? modelContext.fetch(FetchDescriptor<Wallet>())) ?? []
        let walletsById: [UUID: Wallet] = Dictionary(uniqueKeysWithValues: wallets.map { ($0.id, $0) })

        var groups: [WalletStakes] = []
        var totalPrincipal = Decimal(0)
        var totalReward = Decimal(0)
        var totalCount = 0

        for portfolio in portfolios where !portfolio.stakes.isEmpty {
            let display = walletsById[portfolio.walletId]
                .map { WalletListViewModel.displayLabel(for: $0) }
                ?? "—"
            groups.append(WalletStakes(
                walletId: portfolio.walletId,
                walletDisplay: display,
                positions: portfolio.stakes
            ))
            for position in portfolio.stakes {
                totalPrincipal += position.principal
                totalReward += position.estimatedReward
                totalCount += 1
            }
        }
        // Wallets with the largest stake first.
        groups.sort { left, right in
            let leftTotal = left.positions.reduce(Decimal(0)) { $0 + $1.principal }
            let rightTotal = right.positions.reduce(Decimal(0)) { $0 + $1.principal }
            return leftTotal > rightTotal
        }

        walletGroups = groups
        totalStakedSUI = totalPrincipal / Decimal(1_000_000_000)
        totalEstimatedRewardSUI = totalReward / Decimal(1_000_000_000)
        totalPositionCount = totalCount
    }

    func refresh() async {
        let wallets = (try? modelContext.fetch(FetchDescriptor<Wallet>())) ?? []
        for wallet in wallets.filter(\.includeInWidget) {
            _ = try? await stakingService.refresh(walletId: wallet.id)
        }
        load()
        // Stakes feed the widget's stake summary; refresh timelines once we
        // know the cache has new data.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
