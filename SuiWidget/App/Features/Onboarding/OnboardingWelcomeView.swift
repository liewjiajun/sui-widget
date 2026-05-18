import SwiftUI
import SuiWidgetKit

/// Onboarding page 1 (Welcome). Two stacked mock widget previews + tagline + Continue CTA.
struct OnboardingWelcomeView: View {
    let onNext: () -> Void
    /// 0 → 1 cycle drives a ±3pt vertical float on the two stacked widget cards
    /// (anti-phased so they breathe against each other).
    @State private var floatPhase: Double = 0

    var body: some View {
        VStack(spacing: SuiSpacing.s5) {
            Spacer()
            ZStack {
                // Floating mock widget previews — two tilted cards stacked
                RoundedRectangle(cornerRadius: SuiSpacing.widgetRadius, style: .continuous)
                    .fill(SuiColor.suiBlue.opacity(0.18))
                    .frame(width: 200, height: 110)
                    .overlay(
                        HStack {
                            SuiGlyph(size: 20)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("$2,841")
                                    .font(SuiTypography.display(20))
                                Text("▲ 2.4%").font(SuiTypography.mono(11, weight: .bold))
                                    .foregroundStyle(SuiColor.up)
                            }
                        }.padding(12)
                    )
                    .pixelLift()
                    .rotationEffect(.degrees(-4))
                    .offset(x: -16, y: -16 + floatPhase * 3)

                RoundedRectangle(cornerRadius: SuiSpacing.widgetRadius, style: .continuous)
                    .fill(SuiColor.suiTint.opacity(0.4))
                    .frame(width: 200, height: 110)
                    .overlay(
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STAKED · 3").font(SuiTypography.mono(8, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("408 SUI")
                                .font(SuiTypography.display(20))
                            Text("4.8% APY").font(SuiTypography.mono(11, weight: .bold))
                                .foregroundStyle(SuiColor.up)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    )
                    .pixelLift()
                    .rotationEffect(.degrees(3))
                    .offset(x: 16, y: 16 - floatPhase * 3)
            }
            .frame(height: 200)

            VStack(spacing: SuiSpacing.s2) {
                Text("Sui on your screen.\nAlways.")
                    .font(SuiTypography.display(30))
                    .multilineTextAlignment(.center)
                Text("Your Sui portfolio, NFTs, staking and ecosystem news — right on your Home and Lock screens.")
                    .font(SuiTypography.body(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: onNext) {
                Label("Continue", systemImage: "arrow.right")
                    .font(SuiTypography.body(15, weight: .semibold))
                    .padding(.horizontal, SuiSpacing.s5)
                    .padding(.vertical, SuiSpacing.s3)
                    .background(SuiColor.suiBlue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 80)  // Leave room for the dots+skip overlay
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                floatPhase = 1
            }
        }
    }
}
