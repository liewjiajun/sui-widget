import SwiftUI
import SuiWidgetKit

struct StakeRowView: View {
    let position: CachedStakePosition

    var body: some View {
        HStack(spacing: SuiSpacing.s3) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(position.validatorName ?? shortAddress)
                    .font(SuiTypography.body(13, weight: .semibold))
                    .lineLimit(1)
                Text(statusLabel)
                    .font(SuiTypography.mono(9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(suiPrincipalLabel) SUI")
                    .font(SuiTypography.display(13))
                if position.estimatedReward > 0 {
                    Text("~+\(suiRewardLabel) est.")
                        .font(SuiTypography.mono(9))
                        .foregroundStyle(SuiColor.up)
                }
            }
        }
        .padding(SuiSpacing.s3)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(position.validatorName ?? shortAddress), \(suiPrincipalLabel) SUI principal, status \(position.status.rawValue)")
    }

    private var avatar: some View {
        ZStack {
            if let urlString = position.validatorImageURL, let url = URL(string: urlString) {
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
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(SuiColor.suiBlue.opacity(0.18))
            Text(initial).font(SuiTypography.display(13)).foregroundStyle(SuiColor.suiDeep)
        }
    }

    private var initial: String {
        position.validatorName?.first.map { String($0).uppercased() } ?? "?"
    }

    private var shortAddress: String {
        let addr = position.validatorAddress
        guard addr.count > 12 else { return addr }
        return "\(addr.prefix(6))…\(addr.suffix(4))"
    }

    private var statusLabel: String {
        let suffix = position.stakingPool.isEmpty ? "" : " · pool \(String(position.stakingPool.prefix(8)))…"
        return "\(position.status.rawValue)\(suffix)"
    }

    private var suiPrincipalLabel: String {
        let sui = position.principal / Decimal(1_000_000_000)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f.string(from: sui as NSDecimalNumber) ?? "0"
    }

    private var suiRewardLabel: String {
        let sui = position.estimatedReward / Decimal(1_000_000_000)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        return f.string(from: sui as NSDecimalNumber) ?? "0"
    }
}
