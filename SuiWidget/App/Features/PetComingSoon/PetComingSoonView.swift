import SwiftUI
import SuiWidgetKit

struct PetComingSoonView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SuiSpacing.s5) {
                    Spacer().frame(height: SuiSpacing.s4)
                    Text("🥚")
                        .font(.system(size: 96))
                    Text("Hatch a pet · Coming in V2")
                        .font(SuiTypography.display(22))
                        .multilineTextAlignment(.center)
                    Text("Your wallet will earn a soul-bound pixel sea creature, deterministically generated from its address. It'll live in the circular slot on your Medium and Large widgets.")
                        .font(SuiTypography.body(14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                        bullet("Soul-bound — one pet per wallet, forever, non-transferable")
                        bullet("Deterministically generated from the wallet address")
                        bullet("Earn XP from quests (V3)")
                        bullet("Sits in the Medium / Large widget pet slot")
                    }
                    .padding(.horizontal)

                    Spacer().frame(height: SuiSpacing.s4)
                    Button("Got it", action: { dismiss() })
                        .font(SuiTypography.body(15, weight: .semibold))
                        .padding(.horizontal, SuiSpacing.s5)
                        .padding(.vertical, SuiSpacing.s3)
                        .background(SuiColor.suiBlue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding()
            }
            .navigationTitle("Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SuiSpacing.s2) {
            Text("•").foregroundStyle(SuiColor.suiBlue)
            Text(text).font(SuiTypography.body(13))
        }
    }
}
