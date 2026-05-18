import SwiftUI
import SuiWidgetKit
import UserNotifications

/// Paged container that hosts the 3 onboarding screens: Welcome → Notifications → Add Wallet.
/// Per V1 Task 10 / design Flow V2 "illustrative hero".
struct OnboardingCoordinatorView: View {
    let onComplete: () -> Void
    @State private var page: Int = 0
    private let totalPages: Int = 3

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $page) {
                OnboardingWelcomeView(onNext: advance).tag(0)
                OnboardingNotificationsView(onNext: advance, onSkip: advance).tag(1)
                OnboardingAddWalletView(onComplete: onComplete, onSkip: onComplete).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: SuiSpacing.s3) {
                pageDots
                if page < totalPages - 1 {
                    Button("Skip", action: onComplete)
                        .font(SuiTypography.body(13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, SuiSpacing.s5)
        }
        .background(SuiColor.suiPale.opacity(0.4).ignoresSafeArea())
    }

    private var pageDots: some View {
        HStack(spacing: SuiSpacing.s2) {
            ForEach(0..<totalPages, id: \.self) { idx in
                Circle()
                    .fill(idx == page ? SuiColor.suiBlue : SuiColor.flat.opacity(0.4))
                    .frame(width: idx == page ? 10 : 8, height: idx == page ? 10 : 8)
            }
        }
    }

    private func advance() {
        withAnimation { page = min(page + 1, totalPages - 1) }
    }
}
