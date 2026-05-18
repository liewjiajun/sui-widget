# V1 App & Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. All subagents dispatched with `model: "opus"`. Each task = one focused commit. Total ~17 tasks.

**Goal:** Ship the full V1 app + WidgetKit extension on top of the Phase 1 data layer, per `design_handoff_sui_widget/README.md`. Staking visibility is the explicit user priority — Task 4 lands the Stake List screen.

**Architecture:** SwiftUI 4-tab app + 7 WidgetKit variants with `AppIntentConfiguration`. `@Observable` view models, `NavigationStack` per tab, `@Environment` injection of `ModelContext` + Phase 1 services. Widget extension reads App Group SwiftData; never blocks on network.

**Tech Stack:** Swift 5.9, SwiftUI, WidgetKit, AppIntents, SwiftData, SFSafariServices, ImageIO, CryptoKit, Python+PIL (icon generation).

**Reference:** `docs/superpowers/specs/2026-05-18-v1-app-and-widgets-design.md` + `design_handoff_sui_widget/README.md` + `design_handoff_sui_widget/design_files/*.jsx`

---

## Task list (each task = one Opus subagent dispatch + one commit)

1. **Foundation** — design tokens (colors, typography, spacing), `Color+Hex`, `PixelLift`, `SuiGlyph`, `PixelDropletGlyph`, shared `StateView`, `DeepLinkRouter`. Color hex unit tests.
2. **Tab shell** — `SuiWidgetApp` mounts `RootView`; `RootView` is the onboarding gate + deep-link router + `TabView` host with 4 placeholder tab containers, each wrapped in `NavigationStack`.
3. **Wallet management** — `WalletListView` (grouped primary/others) + `WalletAddView` (with SuiNS resolution feedback) + `WalletEditView` (label + primary toggle + include-in-widget toggle + remove) + `WalletListViewModel`. Uses Phase 1 `WalletService` + `SuiNSResolver`.
4. **Portfolio + Stake List (USER GOAL)** — `PortfolioView` (pixel donut + token list + staked badge) + `PortfolioViewModel` + `StakeListView` (hero card + per-validator rows) + `StakeRowView` + `StakeListViewModel` + `TokenDetailView` placeholder. Per `pixel-screens.jsx` PxPortfolio / PxStakeList / PxTokenDetail.
5. **Small Home widget (v1 stack)** — `SuiWidgetConfigurationIntent` (initial parameters), `SuiTimelineProvider` reading App Group SwiftData, `SuiWidgetEntry` with portfolio + state flags, `SmallWidgetView` v1 stack variant. Per `pixel-widgets.jsx` PxSmallWidget.
6. **Medium / Large / ExtraLarge widgets (incl. ExtraLarge staking footer)** — `MediumWidgetView` v1 portfolio + tokens with pet slot, `LargeWidgetView` v1 everything (portfolio + tokens + NFTs + news + pet slot), `ExtraLargeWidgetView` v1 dashboard (3-column + **staking footer**). Per `pixel-widgets.jsx` PxMediumWidget / PxLargeWidget / PxXLWidget.
7. **Lock Screen widgets** — `InlineWidgetView`, `CircularWidgetView` (default 24H delta variant), `RectangularWidgetView`. Monochrome — no color for meaning, ▲/▼/~ glyphs + font weight. Per `pixel-widgets.jsx` PxInline / PxCircular / PxRectangular.
8. **Widget configuration plumbing** — extend `SuiWidgetConfigurationIntent` with full parameter set (variant per size, wallet scope, currency, refresh frequency), wire into provider, ensure long-press → Edit Widget on each size shows the iOS-standard sheet.
9. **Widget Configurator (in-app)** — `WidgetConfiguratorView` with live preview + variant picker tiles + drill rows (wallets, refresh, currency, NFTs). Per `pixel-screens.jsx` PxConfigurator.
10. **Onboarding** — `OnboardingCoordinatorView` with paging + dots indicator + `OnboardingWelcomeView` + `OnboardingNotificationsView` + `OnboardingAddWalletView`. `AppStorage("hasCompletedOnboarding")` flips on completion. Per `pixel-screens.jsx` PxOnboarding*.
11. **NFT Gallery + Detail** — `NFTGalleryView` (3-col grid grouped by collection with in-widget toggle per group) + `NFTDetailView` (full image, attributes, Suiscan link via `SFSafariViewController`) + `NFTGalleryViewModel`. Per `pixel-screens.jsx` PxNFTGallery / PxNFTDetail.
12. **News + Browser** — `NewsView` (editorial hero + list) + `NewsBrowserView` (`SFSafariViewController` UIViewControllerRepresentable wrapper) + `NewsViewModel`. Per `pixel-screens.jsx` PxNews.
13. **Settings** — `SettingsView` with three `Form.insetGrouped` sections (DISPLAY/DATA/ABOUT) + `SettingsViewModel`. Theme toggle applies live via `@AppStorage("preferredColorScheme")`. Per `pixel-screens.jsx` PxSettings.
14. **Pet slot V1** — `PetSlotView` widget component (28pt dashed circle + 🥚 + "Hatch a pet" label) used by Medium/Large variants; "Coming soon" pet screen in app at `Features/PetComingSoon/` deep-linked via `suiwidget://pet/hatch`.
15. **App icon (pixel droplet)** — Python+PIL script generates 16×16 source from `PxDroplet` definition in `pixel-core.jsx`, upscales to 1024×1024 with nearest-neighbor, splits into all required iOS sizes; creates `AppIcon-Tinted.appiconset` (white silhouette) for iOS 18+; wires assets via `project.yml`.
16. **States polish** — apply Loading/Empty/Error/Stale/Offline patterns from `StateView` (Task 1) across PortfolioView, StakeListView, NFTGalleryView, NewsView, and all widget views. Widgets show stale pill when cache > 15min after expected refresh.
17. **Acceptance pass + final code review** — `swift test` green, `xcodebuild` green with zero warnings, `xcodegen generate`, CI green; final reviewer subagent across the entire V1 diff.

## Per-task discipline

Every implementer subagent:
- Reads relevant `.jsx` design reference before writing UI code
- Uses `@Observable` view models (Swift 5.9 macro) for any view that needs state
- Annotates view models `@MainActor`
- Injects `ModelContext` and Phase 1 services via `@Environment` / initializer
- Applies `.monospacedDigit()` on every numeric `Text`
- Uses design tokens from Task 1 (no hardcoded colors/sizes elsewhere)
- Verifies: `swift test` green (no Phase 1 regressions), `xcodebuild build` green with zero warnings, iOS Simulator scheme builds
- Commits with focused subject + `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer
- Reports DONE/DONE_WITH_CONCERNS/BLOCKED with command outputs

## Acceptance criteria (full list in spec §4)

By end of plan: 17+ commits, 4-tab app with onboarding gate, 7 widget variants installable, pixel-droplet app icon, all states implemented, CI green.
