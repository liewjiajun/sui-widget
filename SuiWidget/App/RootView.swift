import SwiftUI
import SwiftData
import SuiWidgetKit

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
                OnboardingCoordinatorView(onComplete: {
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
