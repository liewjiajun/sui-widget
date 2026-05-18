import SwiftUI

/// Placeholder. V1 Task 4 fills in donut + token list + staked badge.
struct PortfolioView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                SuiGlyph(size: 64)
                Text("Portfolio")
                    .font(SuiTypography.display(28))
                Text("Donut + tokens + staking lands in V1 Task 4")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.large)
    }
}
