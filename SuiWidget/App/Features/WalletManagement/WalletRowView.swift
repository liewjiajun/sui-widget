import SwiftUI
import SuiWidgetKit

struct WalletRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let wallet: Wallet
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: SuiSpacing.s3) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(WalletListViewModel.displayLabel(for: wallet))
                    .font(SuiTypography.body(14, weight: .semibold))
                    .lineLimit(1)
                Text(WalletListViewModel.shortAddress(wallet.address))
                    .font(SuiTypography.mono(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isPrimary {
                Text("PRIMARY")
                    .font(SuiTypography.mono(9, weight: .bold))
                    .padding(.horizontal, SuiSpacing.s2)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(SuiColor.suiBlue.opacity(0.18)))
                    .foregroundStyle(SuiColor.suiBlue)
            }
        }
        .padding(.vertical, SuiSpacing.s2)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(SuiColor.suiBlue.opacity(0.18))
            Text(initialLetter)
                .font(SuiTypography.display(14))
                .foregroundStyle(SuiColor.suiDeep)
        }
        .frame(width: 36, height: 36)
    }

    private var initialLetter: String {
        let label = WalletListViewModel.displayLabel(for: wallet)
        return label.first.map { String($0).uppercased() } ?? "?"
    }
}
