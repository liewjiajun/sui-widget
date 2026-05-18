# Phase 1 Preparation Notes

**Created:** 2026-05-17 (end of Phase 0)
**Status:** Resolved 2026-05-18 (during Phase 1 Task 1)
**Source:** Final code review across the full Phase 0 implementation (15 commits, `dd307ee..0d833fc`)

> All pre-schema-registration items below were resolved in Phase 1 Task 1 (commit `91018060`).
> All other items rolled into Phase 1 work where applicable. New Phase 2 follow-ups documented
> in [phase-2-prep.md](phase-2-prep.md).

---

This document captures items the Phase 0 reviewers explicitly deferred. Phase 1 begins with `SuiWidgetKit/SwiftDataStack.schema` being populated; **everything below should be resolved before that first `Schema([...])` registration**, because post-registration changes require a versioned migration.

## Pre-schema-registration items (must do first)

1. **Add `deleteRule: .cascade` to `CachedPortfolio` relationships**
   File: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/PortfolioSnapshot.swift:12-14`
   ```swift
   @Relationship(deleteRule: .cascade) public var tokens: [CachedTokenHolding]
   @Relationship(deleteRule: .cascade) public var stakes: [CachedStakePosition]
   @Relationship(deleteRule: .cascade) public var nfts: [CachedNFTItem]
   ```
   Why: default `.nullify` leaves orphan child rows on portfolio delete; the cache-replacement flow ("delete old snapshot, insert fresh") would silently accumulate rows.

2. **Add `@Attribute(.unique) var id: UUID` to `CachedTokenHolding` and `CachedStakePosition`**
   Files: `Models/PortfolioSnapshot.swift` (`CachedTokenHolding`), `Models/StakePosition.swift` (`CachedStakePosition`)
   Why: upsert-by-natural-key during cache refresh requires a unique attribute; without one, duplicate rows are possible if cascade ever fails.

3. **Decide and enforce `AppSettings` singleton**
   File: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/AppSettings.swift`
   Pattern: `@Attribute(.unique) public var singletonKey: String` defaulted to `"default"`, OR a fetch-or-create coordinator that returns the same row idempotently.
   Why: nothing today prevents `modelContext.insert(AppSettings())` from being called twice and creating two settings rows.

4. **Reconcile `Quest.summary` vs CLAUDE.md `Quest.description`**
   File: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Quest.swift:10`
   The implementation uses `summary` (better Swift — avoids shadowing `CustomStringConvertible.description`); CLAUDE.md says `description`. Update CLAUDE.md to match, or rename back. Either way, do it before registering the model.

5. **`CachedNFTItem.objectId` uniqueness**
   File: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NFTItem.swift`
   Decide whether NFT objectIds should be `@Attribute(.unique)`. They are unique on-chain, but marking them unique here enforces that an NFT can only be in one portfolio snapshot — which may or may not be the desired data model. Phase 0 left it un-marked (matching CLAUDE.md verbatim).

## Code-quality follow-ups (Phase 1 cleanup, not strictly pre-registration)

6. **Enum-ify stringly-typed `status` fields**
   - `CachedStakePosition.status` ("active" / "pending" / "withdrawing")
   - `Quest.status` ("available" / "in_progress" / "completed")
   - `CachedNewsItem.source` ("blog" / "github_release")

   Make each `RawRepresentable: String, Codable` enum. Doing this before Phase 3 UI lands prevents a migration when the views start switching on these values.

7. **Make `AppGroupStore` write/read `async throws`**
   File: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/AppGroupStore.swift`
   Phase 0's 60-byte handshake JSON is fine sync. Phase 1's portfolio snapshot (~50 KB+) on the main thread will jank scroll. Migrate the API before larger payloads arrive.

8. **`#if canImport(UIKit)` guards for iOS-only package code**
   The image pipeline work (Phase 1) will introduce `UIImage` / `ImageIO` calls. Guard those with `#if canImport(UIKit)` or `#if os(iOS)` so `swift test` on macOS keeps working for the rest of the package.

## CI / tooling follow-ups

9. **Add `needs: package-tests` to the `ios-build` job in `.github/workflows/ci.yml`**
   Currently both jobs run in parallel. Gating the iOS build on the package tests makes the CI signal cleaner (no misleading half-green on a broken package change).

10. **Pin XcodeGen version in CI**
    `brew install xcodegen` in CI currently floats with the formula. A breaking XcodeGen release would silently break us. Either pin (`xcodegen@2.x` is not actually a Homebrew tap; prefer caching the installed binary) or accept the risk explicitly.

## Phase 0 UI / widget follow-ups

11. **Replace `SuiWidgetWidget.description` placeholder**
    File: `SuiWidget/Widget/SuiWidgetWidget.swift:14`
    Current: `"Phase 0 placeholder — shows the value written by the app."` — this appears in the user-facing widget gallery. Update before TestFlight (Phase 4 at the latest, Phase 3 ideally).

12. **Rename `Provider/WidgetEntry.swift` → `HandshakeEntry.swift`**
    The type inside is `HandshakeEntry`; the filename should match. Trivial discoverability win for Phase 3 when the entry types multiply.

13. **`HandshakeTimelineProvider.currentEntry()` diagnostic gap**
    File: `SuiWidget/Widget/Provider/TimelineProvider.swift`
    Currently `try?` collapses `containerUnavailable` and `DecodingError` into the same `"(no value)"` display. Distinguishing them (e.g., `"(decode error)"` for the latter) would help diagnose schema drift between app and widget builds in Phase 1+.

14. **Display the handshake's own timestamp, not the provider run time**
    File: `SuiWidget/Widget/SuiWidgetWidget.swift` (`HandshakeWidgetView`)
    Currently shows `Text(entry.date, style: .time)` which is "when the timeline provider ran." Once `HandshakePayload.writtenAt` is surfaced through the entry, switch to that — it answers the more useful question "when did the app actually write this?"

15. **`kind = "SuiWidgetWidget"` is the durable widget identity**
    File: `SuiWidget/Widget/SuiWidgetWidget.swift:7`
    Add a `// FROZEN: do not rename — existing placed widgets use this as their persistence key` comment before any production users exist.

## Project structure

16. **Add `ActivityEvent` model in Phase 1 if V3 hooks need it**
    CLAUDE.md V3 hooks mention `ActivityEvent` ("log wallet syncs, useful for retroactive quest verification"). Phase 0 did not create this file (it isn't in the "Project structure" diagram). Phase 1 can add it when first scaffolding V3 hooks for real.

17. **Quest list screen feature flag**
    CLAUDE.md V3 hooks call for a "Quest list screen ... hidden behind feature flag, ready to enable." Phase 0 has no feature flag plumbing. Phase 1 should introduce the flag mechanism (likely a `FeatureFlags` enum/struct in `SuiWidgetKit`) and the placeholder screen.

## Reviewer-suggested improvements not blocking

- `*.xcuserdatad` line in `.gitignore` is redundant with `xcuserdata/` (Phase 0 reviewer flagged it). Remove on next gitignore touch.
- `version = "0.0.1"` constant on `SuiWidgetKit` enum has no consumer. Either log it in `AppDelegate` for dev builds or delete.
- README "Bootstrap" section should explain that `project.yml` is the source of truth and the `.xcodeproj` is generated — a fresh cloner needs to run `xcodegen generate` before the README's `open SuiWidget.xcodeproj` step works.
