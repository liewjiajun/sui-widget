# Sui Widget

A free, native iOS app that displays a Sui user's portfolio, NFTs, staking positions, and ecosystem news on Home Screen and Lock Screen widgets. See [`CLAUDE.md`](CLAUDE.md) for the full technical brief.

## Prerequisites

- macOS with Xcode 16+ installed
- Homebrew
- `brew install xcodegen`

## Bootstrap

```bash
xcodegen generate                # produces SuiWidget.xcodeproj from project.yml
open SuiWidget.xcodeproj         # then pick a Development Team on both targets
```

## Run the Phase 0 acceptance test

1. Build & run the **SuiWidget** scheme on an iPhone simulator.
2. The app shows the value it just wrote to the `group.io.sui.widget` App Group container.
3. Add the **Sui Handshake** widget to the simulator's Home Screen (long-press, +, search "Sui").
4. Tap **Write again** in the app; the widget timeline reloads and displays the new value.

## Run the package tests

```bash
swift test --package-path Packages/SuiWidgetKit
```

## V1 — Shipping status

The full V1 app + widget extension ship in this build:

- **App (4 tabs):** Portfolio (donut + tokens + staked badge → StakeList drill-in), NFTs (grid grouped by collection, in-widget toggle, Suiscan deep link), News (editorial hero + list + in-app browser), Settings (DISPLAY/DATA/ABOUT)
- **Onboarding:** 3-screen first-launch flow with paging + dots indicator
- **Wallet management:** Add (with live SuiNS resolution), list (PRIMARY/OTHERS groups, swipe actions), edit
- **WidgetKit:** 4 Home Screen sizes (Small/Medium/Large/ExtraLarge with staking footer) + 3 Lock Screen sizes (Inline/Circular/Rectangular) + AppIntentConfiguration for per-instance config
- **In-app Widget Configurator:** Live preview + variant picker + drill rows
- **Pixel-droplet AppIcon:** 1024×1024 source in light/dark/iOS-18-tinted variants
- **Pet V2 hook:** Reserved circular slot in Medium/Large widgets + "Coming soon" sheet via deep link

### Try it

1. `xcodegen generate`
2. Open `SuiWidget.xcodeproj`, select an iPhone 17 simulator destination
3. Build & run; the app launches into the 3-screen onboarding (skip available)
4. Add the test wallet: `0xe6d2886da571e044dd3873d40eba75aa5610c51618f0c48fa0ca376d492d56a8` (Mysten Labs `validator.sui`) or paste your own
5. Pull-to-refresh on Portfolio to fetch live data
6. Tap the **STAKED** badge to drill into the Stake List (where users see their validator positions)
7. Add the **Sui Portfolio** widget to the Home Screen — long-press → Edit Widget surfaces the AppIntent config sheet
8. The **ExtraLarge** widget includes a staking footer showing total staked + position count + APY

### V2 / V3 hooks deliberately stubbed in V1

These are NOT placeholders — they're explicit hooks for future versions per
[`CLAUDE.md`](CLAUDE.md)'s V2 / V3 scaffolding requirements, and they ship in
V1 as stubs:

- **Pet "Coming soon" sheet** (V2 hook): tapping the reserved circular slot on
  Medium / Large widgets — or the `suiwidget://pet/hatch` deep link — opens a
  Coming Soon sheet. The pet generation algorithm + sprite renderer is V2 scope.
- **Quest reminders toggle** in Onboarding step 2: disabled and labeled
  "(coming)". The full Quest list screen is gated behind a feature flag.
- **Pet / Quest SwiftData models**: declared with full schema, registered in
  `SwiftDataStack.schema`, never instantiated in V1. Reserved so V2 / V3 ship
  without schema migration.
- **ActivityEvent model**: declared, registered, never written. V3 retroactive
  quest verification will populate it.

Everything else in V1 is fully functional with no deferred logic.

## Data layer (`SuiWidgetKit`)

`SuiWidgetKit` ships the full data layer:

- **`SuiRPCClient`** — seven Sui RPC methods with endpoint rotation + exponential backoff
- **`CoinGeckoClient`** — coin list (24h TTL) + batched market prices
- **`RSSClient`** — Sui blog + MystenLabs releases feeds, merged + deduped (FeedKit 9.x)
- **`SuiNSResolver`** — `0x...` / `name.sui` / `@name` resolution with 1h cache
- **Image pipeline** — IPFS gateway rotation → ImageIO resize → App Group cache
- **Services** — `WalletService`, `PortfolioService`, `NFTService`, `StakingService`, `NewsService`
- **SwiftData schema** — 13 entities registered

### Run the live integration tests

The fast unit tests (`swift test`) replay committed JSON fixtures and never touch
the network. A separate `@Suite` exercises the whole layer against the live
Sui mainnet + CoinGecko + RSS feeds — disabled by default:

```bash
swift test --package-path Packages/SuiWidgetKit --filter "Live integration"
```

The integration test wallet is `0xe6d2886d…d492d56a8` (`validator.sui`).

## Repo layout

See [`docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md`](docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md) for the authoritative design.
