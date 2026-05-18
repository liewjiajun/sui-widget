import SwiftUI
import SwiftData
import SuiWidgetKit

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("preferredColorScheme") private var preferredColorSchemeRaw: String = AppTheme.system.rawValue
    @Environment(\.modelContext) private var modelContext
    @State private var deepLinkDestination: DeepLinkDestination?
    @State private var selectedTab: AppTab = .portfolio
    @State private var showPetComingSoon: Bool = false
    @State private var portfolioPath: [PortfolioRoute] = []

    enum AppTab: Hashable {
        case portfolio
        case nfts
        case news
        case settings
    }

    /// Navigation stack destinations for the Portfolio tab. Used by deep-link
    /// routing (`suiwidget://stake` pushes `.stakeList(walletId:)`).
    enum PortfolioRoute: Hashable {
        case stakeList(walletId: UUID)
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
            case .wallet:
                selectedTab = .portfolio
            case .stakeList:
                selectedTab = .portfolio
                pushStakeListForPrimaryWallet()
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

    /// Resolves the primary wallet (falls back to first by orderIndex) and
    /// appends StakeListView to the Portfolio tab's navigation stack so the
    /// `suiwidget://stake` deep link lands directly on the stake list view.
    private func pushStakeListForPrimaryWallet() {
        do {
            let wallets = try modelContext.fetch(FetchDescriptor<Wallet>())
            guard let target = wallets.first(where: \.isPrimary) ?? wallets.first else {
                return
            }
            // Clear stale path entries before appending so the deep link always
            // lands directly on the freshly-pushed stake list.
            portfolioPath = [.stakeList(walletId: target.id)]
        } catch {
            // Silent failure — user remains on Portfolio root.
        }
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $portfolioPath) {
                PortfolioView()
                    .navigationDestination(for: PortfolioRoute.self) { route in
                        switch route {
                        case .stakeList(let walletId):
                            StakeListView(walletId: walletId)
                        }
                    }
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
