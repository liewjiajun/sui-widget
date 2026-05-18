import SwiftUI
import SuiWidgetKit

/// Used by ExtraLargeWidgetView. Shows total staked + positions + APY in a row.
public struct StakedFooter: View {
    public let stakes: StakeSummary

    public init(stakes: StakeSummary) {
        self.stakes = stakes
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(SuiColor.up)
            VStack(alignment: .leading, spacing: 1) {
                Text("STAKED")
                    .font(SuiTypography.mono(8, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("\(suiAmount) SUI · \(stakes.positionCount) \(stakes.positionCount == 1 ? "position" : "positions")")
                    .font(SuiTypography.body(11, weight: .semibold))
                    .contentTransition(.numericText())
            }
            Spacer()
            if let apy = stakes.weightedAPY {
                Text(String(format: "%.1f%% APY", apy))
                    .font(SuiTypography.mono(11, weight: .bold))
                    .foregroundStyle(SuiColor.up)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SuiColor.up.opacity(0.10))
        )
    }

    private var suiAmount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f.string(from: stakes.totalSUI as NSDecimalNumber) ?? "0"
    }
}
