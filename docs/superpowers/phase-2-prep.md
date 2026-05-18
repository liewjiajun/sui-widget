# Phase 2 Preparation Notes

**Created:** 2026-05-18 (end of Phase 1)
**Source:** Phase 1 implementation review (commits `91018060..cae6e58`, plus the
Task 12 services landing)

Phase 2 ("Main app UI") begins by addressing the items below before wiring the
services into SwiftUI screens.

## Data-layer corrections to make before Phase 2 UI

1. **Coin-type canonicalization (Sui short form ↔ long form)** — Sui RPC returns
   `0x2::sui::SUI` while the CoinGecko coin list uses the long form
   `0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI`.
   The PortfolioService currently treats short-form SUI balances as untracked. Add
   a `String.canonicalSuiCoinType` helper that left-pads the package address to 64
   hex chars; apply on both sides of the lookup (mapping keys + balance coinTypes).
   Files: `PortfolioService.swift`, `CoinGeckoClient.swift` (when persisting
   `CachedCoinListEntry`), or a new `Utilities/CoinType.swift`. Phase 1
   `PortfolioServiceTests.test_tracked_and_untracked_split` documents the current
   behavior.

2. **NFT thumbnail writeback via ModelActor** — `NFTService.refresh` triggers
   thumbnail generation in `Task.detached`. The detached task currently only writes
   the JPEG file to disk; it does NOT update `CachedNFTItem.thumbnailFilePath`
   because writing back to `ModelContext` from a detached task requires a
   `ModelActor` for thread-safe SwiftData mutations. Plan: introduce a
   `ThumbnailWriteActor: ModelActor` that owns its own `ModelContext` and exposes
   `apply(objectId:thumbnailURL:)`; have the detached task hop to that actor to
   write back. Reconciliation today happens implicitly on next refresh.
   Files: `NFTService.swift`, new `Storage/ThumbnailWriteActor.swift`.

3. **`StakingService.mapStatus` is loosely typed** — currently maps `"Active"` /
   `"Pending"` / `"Unstaked"` from the wire to `.active` / `.pending` /
   `.withdrawing`. Anything else falls back to `.pending`, which is wrong for an
   unknown state. Make `StakeStatus` an `init?(rpcRawValue:)` factory that returns
   nil for unknown values, then drop the position with a logged warning.

4. **`Decimal` arithmetic in `PortfolioService`** — current `pow(10.0, Double(decimals))`
   path converts to `Double` and back, losing precision for large balances. Use
   `Decimal`'s `Foundation.pow(_:_:)` or build a power-of-ten Decimal via repeated
   multiplication. Files: `PortfolioService.swift`.

5. **Hardcoded `decimalsFor(coinType:)` returning 9** — works for SUI but not for
   USDC (6), tether (6), etc. Either: (a) precompute decimals in the coin list
   cache by calling `suix_getCoinMetadata` per Sui-tracked coin once during
   `refreshCoinList`, OR (b) cache decimals per coin type on demand via a new
   `CachedCoinMetadata` table. Either way: drop the placeholder.

## App-target wiring (Phase 2 implementation work)

6. **`@UIApplicationDelegateAdaptor`** in `SuiWidgetApp` already wires `AppDelegate`
   (Phase 0). Populate `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
   to register BGTaskScheduler identifiers:
   - `io.sui.widget.refresh` (BGAppRefreshTask, 30 min)
   - `io.sui.widget.cleanup` (BGProcessingTask, weekly)
   - `io.sui.widget.coinlist` (BGAppRefreshTask, daily)
   Also add `BGTaskSchedulerPermittedIdentifiers` to the app's Info.plist via the
   XcodeGen target settings.

7. **WidgetCenter reload triggers** — Phase 2 services should call
   `WidgetCenter.shared.reloadAllTimelines()` from the UI layer after a successful
   refresh. Keep services UI-agnostic; the call site is in app `ViewModel`s.

8. **Pet sprite layer assets** — Phase 0 V2 hook locks the sea-creature pixel-art
   style. Phase 2 doesn't render pets but should reserve `App/Resources/PetSprites/`
   for the eventual layer PNGs.

9. **Feature flag mechanism** — V3 Quest list screen needs a flag-gated entry
   point. Introduce a tiny `FeatureFlags` enum/struct in `SuiWidgetKit` with
   `static let questsEnabled = false` for now.

## Test infrastructure follow-ups

10. **Pin XcodeGen version in CI** — Phase 0 prep item still open; `brew install
    xcodegen` floats with formula. Either pin or `actions/cache` the binary.

11. **Snapshot tests for widget views** — Phase 3 concern, but the harness should
    be agreed on (PointFree's `SnapshotTesting` is the standard). Mention now so
    Phase 3 doesn't re-design.

## Documentation

12. **Update CLAUDE.md "Architecture" diagram** to reflect the actual file
    structure under `SuiWidgetKit/` (Models, Networking, Services, Storage,
    Utilities) — currently the diagram is high-level and mostly accurate but
    doesn't show the new entities.

## V1 UI / Widget follow-ups (added 2026-05-18)

- **Auto-push StakeListView on `suiwidget://stake` deep link.** Today the deep
  link switches to the Portfolio tab but doesn't auto-push StakeListView; the
  user has to tap the STAKED badge. Wire via `NavigationStack(path:)`.
- **Per-widget instance configuration write-back.** The in-app Widget
  Configurator is preview-only; it doesn't write per-instance config back to
  any specific widget. The system Edit Widget sheet is the canonical write
  path. V1.1 should add a way to share configuration presets via App Group.
- **WidgetCenter reload trigger on data refresh.** PortfolioView.refresh()
  calls into the data layer but does NOT call WidgetCenter.shared.reloadAllTimelines().
  Add the call so widgets refresh immediately after an app-triggered refresh
  completes.
- **`Wallet.includeInWidget` model flag.** `WalletEditViewModel.includeInWidget`
  is UI-only. The widget extension currently treats the primary wallet as the
  source. V1.1 should add the flag to the @Model and let widgets read multi-
  wallet aggregates.
- **Real token price chart in TokenDetailView.** Placeholder copy ships in V1.
  V1.1 should add a sparkline or chart backed by CoinGecko's `/coins/{id}/market_chart`.
- **Per-validator stake detail.** Tapping a StakeRowView is a no-op in V1.
  V1.1 should push to a detail showing commission, epoch history, rewards.
- **Real refresh frequency wiring.** Settings has the picker; widget configurator
  has the picker. The actual scheduling between app foreground refreshes and
  widget timeline expiry is approximate (15-min default with no enforcement).
  V1.1 should honor the chosen frequency via a foreground timer and the AppIntent's
  refresh parameter.
