import SwiftUI
import SwiftData
import SafariServices
import SuiWidgetKit

struct ValidatorDetailView: View {
    let position: CachedStakePosition
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ValidatorDetailViewModel?
    @State private var safariURL: NewsBrowserURL?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        let vm = ValidatorDetailViewModel(position: position, modelContext: modelContext)
                        vm.load()
                        viewModel = vm
                    }
            }
        }
        .navigationTitle(position.validatorName ?? "Validator")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { wrapper in SafariView(url: wrapper.url) }
    }

    @ViewBuilder
    private func content(viewModel: ValidatorDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                heroCard(viewModel: viewModel)
                statusCard(viewModel: viewModel)
                if let description = viewModel.validator?.validatorDescription, !description.isEmpty {
                    descriptionCard(text: description)
                }
                metadataCard(viewModel: viewModel)
                explorerLink
            }
            .padding()
        }
    }

    private func heroCard(viewModel: ValidatorDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            HStack(spacing: SuiSpacing.s3) {
                validatorAvatar(viewModel: viewModel)
                VStack(alignment: .leading, spacing: 2) {
                    Text(position.validatorName ?? shortAddress(position.validatorAddress))
                        .font(SuiTypography.display(20))
                    Text(String(format: "%.2f%% effective APY", viewModel.effectiveAPYPercent))
                        .font(SuiTypography.mono(11, weight: .bold))
                        .foregroundStyle(SuiColor.up)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: SuiSpacing.s1) {
                Text("YOUR STAKE").font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
                Text("\(formattedSUI(viewModel.principalSUI)) SUI")
                    .font(SuiTypography.pixelDisplay(32))
                    .contentTransition(.numericText())
                if viewModel.rewardSUI > 0 {
                    Text("+ \(formattedSUI(viewModel.rewardSUI)) SUI estimated reward")
                        .font(SuiTypography.mono(11, weight: .bold))
                        .foregroundStyle(SuiColor.up)
                }
            }
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                .fill(SuiColor.up.opacity(0.10))
        )
    }

    private func validatorAvatar(viewModel: ValidatorDetailViewModel) -> some View {
        ZStack {
            if let urlString = viewModel.validator?.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(SuiColor.suiBlue.opacity(0.18))
            Text(initial)
                .font(SuiTypography.display(22))
                .foregroundStyle(SuiColor.suiDeep)
        }
    }

    private var initial: String {
        position.validatorName?.first.map { String($0).uppercased() } ?? "?"
    }

    @ViewBuilder
    private func statusCard(viewModel: ValidatorDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("STATUS").font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
            HStack {
                Text("Position state").font(SuiTypography.body(12, weight: .semibold))
                Spacer()
                statusPill(viewModel: viewModel)
            }
            HStack {
                Text("Commission").font(SuiTypography.body(12, weight: .semibold))
                Spacer()
                Text(String(format: "%.2f%%", viewModel.commissionRatePercent))
                    .font(SuiTypography.mono(12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func statusPill(viewModel: ValidatorDetailViewModel) -> some View {
        let label = position.status.rawValue.uppercased()
        let color: Color = {
            switch position.status {
            case .active: return SuiColor.up
            case .pending: return SuiColor.amber
            case .withdrawing: return SuiColor.coral
            }
        }()
        return Text(label)
            .font(SuiTypography.mono(10, weight: .bold))
            .padding(.horizontal, SuiSpacing.s2)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }

    private func descriptionCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("ABOUT VALIDATOR").font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
            Text(text).font(SuiTypography.body(13))
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func metadataCard(viewModel: ValidatorDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            Text("METADATA").font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
            HStack(alignment: .top) {
                Text("Validator").font(SuiTypography.body(12, weight: .semibold))
                Spacer()
                Text(shortAddress(position.validatorAddress)).font(SuiTypography.mono(10)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            HStack(alignment: .top) {
                Text("Staking pool").font(SuiTypography.body(12, weight: .semibold))
                Spacer()
                Text(shortAddress(position.stakingPool)).font(SuiTypography.mono(10)).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(SuiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var explorerLink: some View {
        Button(action: {
            let url = "https://suiscan.xyz/mainnet/validator/\(position.validatorAddress)"
            if let urlObj = URL(string: url) { safariURL = NewsBrowserURL(url: urlObj) }
        }) {
            HStack {
                Text("View on Suiscan").font(SuiTypography.body(13, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
            .padding(SuiSpacing.s3)
            .background(
                RoundedRectangle(cornerRadius: SuiSpacing.cardRadius)
                    .fill(SuiColor.suiBlue.opacity(0.10))
            )
            .foregroundStyle(SuiColor.suiBlue)
        }
        .padding(.bottom, SuiSpacing.s4)
    }

    private func formattedSUI(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "0"
    }

    private func shortAddress(_ addr: String) -> String {
        guard addr.count > 12 else { return addr }
        return "\(addr.prefix(6))…\(addr.suffix(4))"
    }
}
