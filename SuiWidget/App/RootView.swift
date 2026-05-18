import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var deepLinkDestination: DeepLinkDestination?
    @State private var selectedTab: AppTab = .portfolio

    enum AppTab: Hashable {
        case portfolio
        case nfts
        case news
        case settings
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                tabShell
            } else {
                OnboardingPlaceholderView(onComplete: {
                    hasCompletedOnboarding = true
                })
            }
        }
        .onOpenURL { url in
            guard let destination = DeepLinkRouter.destination(from: url) else { return }
            deepLinkDestination = destination
            switch destination {
            case .wallet, .stakeList:
                selectedTab = .portfolio
            case .nft:
                selectedTab = .nfts
            case .news:
                selectedTab = .news
            case .petHatch:
                selectedTab = .portfolio  // pet hatch lives in Portfolio's drill-in for now
            }
        }
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PortfolioView()
            }
            .tabItem {
                Label("Portfolio", systemImage: "chart.pie.fill")
            }
            .tag(AppTab.portfolio)

            NavigationStack {
                NFTGalleryView()
            }
            .tabItem {
                Label("NFTs", systemImage: "square.grid.2x2.fill")
            }
            .tag(AppTab.nfts)

            NavigationStack {
                NewsView()
            }
            .tabItem {
                Label("News", systemImage: "newspaper.fill")
            }
            .tag(AppTab.news)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
        .tint(SuiColor.suiBlue)
    }
}

/// Placeholder onboarding view used until Task 10 ships the real 3-screen flow.
/// Just a single button that flips the completion flag so the rest of V1 development
/// can ignore the onboarding gate.
struct OnboardingPlaceholderView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: SuiSpacing.s4) {
            Spacer()
            SuiGlyph(size: 96)
            Text("Sui on your screen.\nAlways.")
                .font(SuiTypography.display(28))
                .multilineTextAlignment(.center)
            Text("Onboarding placeholder — full 3-screen flow lands in Task 10.")
                .font(SuiTypography.body(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button(action: onComplete) {
                Text("Continue ▶")
                    .font(SuiTypography.body(15, weight: .semibold))
                    .padding(.horizontal, SuiSpacing.s5)
                    .padding(.vertical, SuiSpacing.s3)
                    .background(SuiColor.suiBlue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.bottom, SuiSpacing.s5)
        }
        .padding()
    }
}
