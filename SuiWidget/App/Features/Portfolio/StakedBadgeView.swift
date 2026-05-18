import SwiftUI
import SuiWidgetKit

/// Drill-in badge shown on the Portfolio screen when stakes exist.
/// Tap pushes StakeListView. Matches the design's "$XXX staked" pill from the
/// Portfolio donut → Stake List drill-in.
struct StakedBadgeView: View {
    let summary: PortfolioViewModel.StakeSummary

    var body: some View {
        HStack(spacing: SuiSpacing.s3) {
            ZStack {
                Circle()
                    .fill(SuiColor.up.opacity(0.18))
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(SuiColor.up)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("STAKED")
                    .font(SuiTypography.mono(9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(suiAmountLabel)
                    .font(SuiTypography.display(16))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(summary.positionCount) " + (summary.positionCount == 1 ? "position" : "positions"))
                    .font(SuiTypography.body(12, weight: .medium))
                Image(systemName: "chevron.right")
                    .font(SuiTypography.body(11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SuiSpacing.s3)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(SuiColor.up.opacity(0.08))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Staked \(suiAmountLabel) across \(summary.positionCount) positions, tap to view")
    }

    private var suiAmountLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let str = formatter.string(from: summary.totalUSD as NSDecimalNumber) ?? "0"
        return "\(str) SUI"
    }
}
