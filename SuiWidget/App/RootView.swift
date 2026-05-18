import SwiftUI
import SwiftData
import SuiWidgetKit

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("preferredColorScheme") private var preferredColorSchemeRaw: String = AppTheme.system.rawValue
    @State private var deepLinkDestination: DeepLinkDestination?
    @State private var selectedTab: AppTab = .portfolio
    @State private var showPetComingSoon: Bool = false

    enum AppTab: Hashable {
        case portfolio
        case nfts
        case news
        case settings
    }

    private var themeColorScheme: ColorScheme? {
        AppTheme(rawValue: preferredColorSchemeRaw)?.colorScheme
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
        .preferredColorScheme(themeColorScheme)
        .onOpenURL { url in
            guard let destination = DeepLinkRouter.destination(from: url) else { return }
            deepLinkDestination = destination
            switch destination {
            case .wallet, .stakeList:
                // V1: stakeList deep link drops user on Portfolio tab; tap STAKED
                // badge to drill in. Auto-push to StakeListView via
                // NavigationStack.path lands in V1.1.
                selectedTab = .portfolio
            case .nft:
                selectedTab = .nfts
            case .news:
                selectedTab = .news
            case .petHatch:
                showPetComingSoon = true
            }
        }
        .sheet(isPresented: $showPetComingSoon) {
            PetComingSoonView()
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
