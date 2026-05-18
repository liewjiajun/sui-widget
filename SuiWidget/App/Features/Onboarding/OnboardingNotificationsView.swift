import SwiftUI
import SuiWidgetKit
import UserNotifications

/// Onboarding page 2 (Notifications). Bell glyph + opt-in toggles + Allow / Not now CTAs.
struct OnboardingNotificationsView: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var refreshConfirmation: Bool = false
    @State private var bigPortfolioChange: Bool = true

    var body: some View {
        VStack(spacing: SuiSpacing.s5) {
            Spacer().frame(height: SuiSpacing.s5)

            ZStack {
                Circle()
                    .fill(SuiColor.suiTint.opacity(0.5))
                    .frame(width: 120, height: 120)
                Image(systemName: "bell.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(SuiColor.suiDeep)
            }

            VStack(spacing: SuiSpacing.s2) {
                Text("Optional · ping me on refresh.")
                    .font(SuiTypography.display(22))
                    .multilineTextAlignment(.center)
                Text("Get notified when your data syncs, or when big movements happen.")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: SuiSpacing.s2) {
                togglePill(title: "Refresh confirmation", isOn: $refreshConfirmation, disabled: false)
                togglePill(title: "Big portfolio change", isOn: $bigPortfolioChange, disabled: false)
                togglePill(title: "(coming) Quest reminders", isOn: .constant(false), disabled: true)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: SuiSpacing.s2) {
                Button(action: requestPermission) {
                    Text("Allow notifications")
                        .font(SuiTypography.body(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SuiSpacing.s3)
                        .background(SuiColor.suiBlue, in: Capsule())
                        .foregroundStyle(.white)
                }
                Button("Not now", action: onSkip)
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SuiSpacing.s5)
            .padding(.bottom, 80)
        }
        .padding()
    }

    @ViewBuilder
    private func togglePill(title: String, isOn: Binding<Bool>, disabled: Bool) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(SuiTypography.body(14, weight: .medium))
        }
        .disabled(disabled)
        .padding(SuiSpacing.s3)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .opacity(disabled ? 0.5 : 1)
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            DispatchQueue.main.async { onNext() }
        }
    }
}
