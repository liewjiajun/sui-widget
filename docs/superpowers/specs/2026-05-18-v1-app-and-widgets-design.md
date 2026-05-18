# V1 — App & Widgets Implementation Design

**Status:** Approved 2026-05-18
**Scope:** Complete V1 per `design_handoff_sui_widget/README.md` — onboarding, 4-tab app, 7 widget variants, configurator, pixel-droplet icon
**Reference:** `design_handoff_sui_widget/README.md` is canonical for visual/behavior; `design_handoff_sui_widget/design_files/*.jsx` show component shapes; `design_handoff_sui_widget/design_files/Sui Widget Pixel Direction.html` is the picked-direction reference

## 1. Context

Phase 1 shipped the full data layer (`SuiWidgetKit`). V1 is the UI layer + WidgetKit extension that consumes that layer. The user's explicit priority within V1: **staking visibility** — every user should be able to see where they are staking by drilling into the Stake List screen from the Portfolio tab, and the staking footer must appear in the ExtraLarge widget variant.

The build order in §15 puts the staking-priority deliverables at steps 3-5 of 17; if execution stalls, the staking goal still ships before non-staking V1 polish.

## 2. Goals

- Onboarding (3 screens per design), persisted via `AppStorage("hasCompletedOnboarding")`
- 4-tab `TabView`: Portfolio · NFTs · News · Settings (wallet management lives in Settings + a sheet from Portfolio header)
- Portfolio screen with pixel donut + token list + staked badge → drills to Stake List
- **Stake List screen** (per `PxStakeList` in `pixel-screens.jsx:801`) — hero card + per-validator rows, pull-to-refresh
- Wallet management (list grouped primary/others, add with SuiNS resolution, edit, remove with swipe)
- NFT Gallery (grid grouped by collection, per-collection widget toggle, NFT Detail)
- News (editorial hero + list, in-app `SFSafariViewController`)
- Widget Configurator (live preview + variant picker, drill-rows for wallets/refresh/currency/NFTs)
- Settings (DISPLAY/DATA/ABOUT groups in `Form.insetGrouped`)
- 4 Home Screen widget sizes + 3 Lock Screen widget sizes, each with `AppIntentConfiguration` (variant + wallet + currency + refresh)
- ExtraLarge home widget includes **staking footer** (3-column dashboard + staking row)
- Pet slot reserved on Medium/Large (28pt circle, "Hatch a pet" → `suiwidget://pet/hatch` → coming-soon screen)
- Pixel droplet app icon (1024×1024 source, all iOS sizes, iOS 18+ tinted variant)
- Deep links: `suiwidget://wallet/{id}`, `suiwidget://stake`, `suiwidget://nft/{objectId}`, `suiwidget://news/{itemId}`, `suiwidget://pet/hatch`
- All states implemented per design: Loading (skeleton), Empty (CTA), Error (last cached + retry pill), Stale (⌛ pill at >15min), Offline (📡 glyph)

## 3. Non-goals (deferred)

- QR scanner (UI shows disabled `coming soon` pill)
- Real token price chart in TokenDetailView (placeholder)
- Per-validator stake detail screen (rows are non-tappable at Stake List level)
- Localization beyond English (layout accommodates dynamic widths via intrinsic content size; strings hardcoded English)
- Pet generation algorithm + sprite rendering (V2; slot exists in widgets, "Hatch a pet" deep-link to coming-soon)
- Quest list + XP (V3)
- BGTaskScheduler actual handlers — identifiers registered in `Info.plist` and `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, but the handlers are no-op for V1 (actual refresh runs on app foreground / widget timeline)
- Coin-type canonicalization (Phase 1 prep #1 carry-over) — SUI short form may show as untracked in Portfolio for V1; ExtraLarge widget staking footer is unaffected since it uses `StakingService` directly
- NFT thumbnail writeback via ModelActor (Phase 1 prep #2) — thumbnails generate but reconciliation lands on next refresh cycle
- Analytics

## 4. Acceptance criteria

1. Fresh install → onboarding (3 screens, skip-anywhere); after completion `hasCompletedOnboarding = true` and the gate routes to TabView
2. WalletAdd accepts `0x...`, `name.sui`, `@name`; SuiNS feedback states (✓/resolving/✗) visible
3. Portfolio shows pixel donut + token rows + staked badge (when stakes > 0)
4. Tap staked badge → StakeListView shows hero card + per-validator rows
5. StakeListView pull-to-refresh triggers `StakingService.refresh(walletId:)`
6. NFT Gallery grouped by collection with in-widget toggle; tap → NFT Detail
7. News tab editorial layout; tap → in-app browser
8. Settings: theme toggle (Light/Dark/System) applies live; currency persists; clear cache empties App Group thumbnails
9. Each Home Screen widget size renders the v1 default variant against live cached data
10. Each Lock Screen widget size renders in monochrome (no color)
11. Long-press widget → Edit Widget → `AppIntentConfiguration` sheet works for all variants
12. In-app Widget Configurator shows live preview + variant tiles
13. ExtraLarge widget includes the staking footer with total staked + position count
14. Deep links (`suiwidget://stake`, etc.) open correct screen
15. Pixel-droplet app icon installed at all iOS sizes + tinted variant available
16. `swift test --package-path Packages/SuiWidgetKit` continues green (no Phase 1 regressions)
17. `xcodebuild build` succeeds for iOS Simulator destination with zero warnings
18. CI green on both jobs

## 5. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| UI framework | SwiftUI only | iOS 17+ minimum; no UIKit interop except `SFSafariViewController` wrapper |
| State pattern | `@Observable` view models (iOS 17 macro); `@Environment` injects services + `ModelContext` | Modern Swift concurrency; testable; no global state |
| Navigation | `NavigationStack` per tab; `TabView` at root | iOS 17 standard; deep link router via `RootView.onOpenURL` |
| View model concurrency | `@MainActor` by default on view models | All UI mutations on main; services are non-`MainActor` and use `async/await` |
| Pixel-lift shadow | App-screen cards only; never on widgets (iOS adds its own clip) | Per design README §"Shadows / lift" |
| Color palette | Per design README §"Colors"; `Color(hex:)` initializer in `Color+Hex.swift` | Hex-string convenience matches design tokens verbatim |
| Typography | SF Pro Display/Text + SF Mono; `.monospacedDigit()` on every numeric Text | Locked by brief; tabular figures for stable widths |
| Spacing tokens | `SuiSpacing.s1`–`s5` (4/8/12/16/24pt); `widgetRadius=22`, `cardRadius=12` | Per design README §"Spacing & layout" |
| Onboarding persistence | `AppStorage("hasCompletedOnboarding")` (UserDefaults via App Group) | Survives reinstall via iCloud keychain not used (V2 consideration) |
| Wallet management surface | Lives in Settings AND as a sheet from Portfolio header pill | Both entries land in `WalletListView` per design |
| Widget configuration | `AppIntentConfiguration` with `WidgetConfigurationIntent` defining 4 parameters | iOS 17+ standard; per-instance config |
| Widget data source | App Group SwiftData (`SwiftDataStack.makeContainer(inMemory: false)`) + raw file cache for thumbnails | Already wired in Phase 1; widgets never block on network |
| Pet slot V1 | 28pt circle with dashed border + 🥚 glyph + "Hatch a pet" label; tap deep-links to coming-soon | Reserved V2 hook per design |
| News browser | `SFSafariViewController` wrapped in `UIViewControllerRepresentable` | Per design README §"News" |
| Deep link routing | `DeepLinkRouter` parses `suiwidget://` URLs into `Destination` enum cases consumed by `RootView` | Single source of truth |
| Pixel droplet generation | Python+PIL script generates 16×16 source from `PxDroplet` definition (in `pixel-core.jsx`) → nearest-neighbor upscale to 1024×1024 | Reproducible pixel-perfect output |
| `swift test` parity | All Phase 1 unit tests stay; no new UI-layer unit tests required for V1 (XCUITest covers app launch; UI testing depth deferred to Phase 4 polish) | UI tests on SwiftUI views via XCUITest are flaky and slow; defer until structure stabilizes |
| Coin-type canonicalization | Apply on read in PortfolioViewModel: when Sui RPC returns `0x2::sui::SUI`, also try `0x00…02::sui::SUI` against the CoinGecko mapping cache | Lightweight Phase 2 fix without invasive refactor of Phase 1 services |

## 6. Source-of-truth references

For every section below, the design handoff has the authoritative visual spec. Implementer subagents should read the specific `.jsx` reference before building each component:

- **Onboarding** → `pixel-screens.jsx:PxOnboarding*` or `screens.jsx:Onboarding*`
- **Portfolio** → `pixel-screens.jsx:PxPortfolio` (look for donut layout + token list)
- **Stake List** → `pixel-screens.jsx:PxStakeList` (line 801, full implementation shown in design)
- **Wallets** → `pixel-screens.jsx:PxWalletList` + `PxWalletAdd` + `PxWalletEdit`
- **NFT Gallery** → `pixel-screens.jsx:PxNFTGallery` + `PxNFTDetail`
- **News** → `pixel-screens.jsx:PxNews`
- **Configurator** → `pixel-screens.jsx:PxConfigurator`
- **Settings** → `pixel-screens.jsx:PxSettings`
- **Widget variants** → `pixel-widgets.jsx` (PxSmallWidget, PxMediumWidget, PxLargeWidget, PxXLWidget, PxInline, PxCircular, PxRectangular)

## 7. File structure

See the full tree in the brainstorming proposal (already approved by user). Highlights:

- `SuiWidget/App/DesignSystem/` — DesignTokens, Color+Hex, PixelLift, SuiGlyph
- `SuiWidget/App/Features/<Feature>/` — Views + ViewModels per feature
- `SuiWidget/App/Shared/` — StateView, PixelDropletGlyph, PixelSparklineView, DeepLinkRouter
- `SuiWidget/App/Resources/Assets.xcassets/` — populated AppIcon + AppIcon-Tinted sets
- `SuiWidget/Widget/Intents/SuiWidgetConfigurationIntent.swift` — `AppIntent` with 4 parameters
- `SuiWidget/Widget/Provider/SuiTimelineProvider.swift` — `AppIntentTimelineProvider`
- `SuiWidget/Widget/HomeScreen/{Small,Medium,Large,ExtraLarge}WidgetView.swift`
- `SuiWidget/Widget/LockScreen/{Inline,Circular,Rectangular}WidgetView.swift`
- `SuiWidget/Widget/Components/` — DeltaGlyph, PixelSparkline, PortfolioValueText, StakedFooter, PetSlotView

## 8. Architecture diagram

```
RootView (onAppear: deep-link router, AppStorage gate)
├── if !hasCompletedOnboarding → OnboardingCoordinatorView
│   ├── Welcome → Notifications → AddWallet → completes
└── else → TabView
    ├── Portfolio tab (NavigationStack)
    │   ├── PortfolioView
    │   │   ├── PortfolioDonutView
    │   │   ├── TokenRowView (list)
    │   │   └── StakedBadgeView → NavigationLink → StakeListView
    │   ├── TokenDetailView (push)
    │   └── StakeListView (push)
    ├── NFTs tab (NavigationStack)
    │   ├── NFTGalleryView
    │   └── NFTDetailView (push)
    ├── News tab (NavigationStack)
    │   ├── NewsView
    │   └── NewsBrowserView (sheet, SFSafariViewController)
    └── Settings tab (NavigationStack)
        ├── SettingsView
        ├── WalletListView (push)
        ├── WalletAddView (sheet)
        ├── WalletEditView (push)
        └── WidgetConfiguratorView (push)
```

Widget extension is wholly separate; the only coupling is the shared App Group SwiftData container and the deep-link URL scheme.

## 9. Implementation order (preview of the plan)

1. **Foundation:** Design tokens + Color+Hex + PixelLift + SuiGlyph + Shared StateView + DeepLinkRouter + Color-hex unit tests
2. **Tab shell + gate:** SuiWidgetApp updates, RootView, TabView with 4 empty tab containers, NavigationStacks
3. **Wallet management:** WalletListView + WalletAddView + WalletEditView + WalletListViewModel (uses Phase 1 WalletService + SuiNSResolver)
4. **Portfolio + Stake List (USER GOAL):** PortfolioView + PortfolioDonutView + TokenRowView + StakedBadgeView + PortfolioViewModel + **StakeListView + StakeRowView + StakeListViewModel** + TokenDetailView placeholder
5. **Small Home widget (v1 stack):** AppIntent skeleton + provider + entry + view; confirms App Group plumbing
6. **Medium + Large + ExtraLarge Home widgets** (incl. ExtraLarge **staking footer**)
7. **Lock Screen widgets** (Inline + Circular + Rectangular, monochrome)
8. **Widget configuration:** AppIntentConfiguration parameters wired through provider; variant picker handled by iOS
9. **Widget Configurator screen (in-app):** live preview + variant tiles + drill rows
10. **Onboarding (3 screens):** Welcome + Notifications + AddWallet + dots indicator
11. **NFT Gallery + Detail**
12. **News + Browser**
13. **Settings**
14. **Pet slot V1:** PetSlotView in widget components + Pet Coming-Soon screen in app + deep link routing
15. **App icon:** pixel droplet sprite generator + all iOS sizes + tinted variant
16. **States polish:** Loading skeletons + Empty/Error/Stale/Offline across all views
17. **Acceptance pass + final code review + commit**

Each step ends with a focused commit. Total ~17 commits, executed via Opus subagents per task.

## 10. Test strategy

- **Phase 1 unit tests continue passing** — every plan task verifies `swift test --package-path Packages/SuiWidgetKit` is green at commit time
- **iOS xcodebuild** — every task verifies `xcodebuild build -scheme SuiWidget -destination 'generic/platform=iOS Simulator'` succeeds with zero warnings
- **One smoke XCUITest** — updated `PlaceholderUITests.test_appLaunches` to assert the TabView appears after onboarding (or that onboarding's first screen appears on cold launch)
- **Deeper UI testing deferred to V1.1** — Phase 4 polish in CLAUDE.md covers full UI test coverage with snapshot tests

## 11. Self-review pass

Implementer subagents include a self-review step:
- Phase 1 tests still green
- iOS build green with zero warnings
- New file count matches expectations
- Per-task commit subject + Co-Author trailer correct
- Visual fidelity matches the referenced `.jsx` component (read the spec before building each piece)
