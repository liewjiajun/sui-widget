# Phase 1 — Data Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. All subagents dispatched with `model: "opus"` per user instruction. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the full data layer for Sui Widget — networking foundation, four API clients (Sui RPC, CoinGecko, RSS, SuiNS), image pipeline, SwiftData schema with all entities registered, and a minimal Services layer that orchestrates them. Every networked type tested against committed JSON fixtures (no live network in `swift test`); a single disabled-by-default integration test exercises the whole stack against a public mainnet wallet.

**Architecture:** Per `docs/superpowers/specs/2026-05-18-phase-1-data-layer-design.md`. Shared `HTTPClient` (struct) handles retry + exponential backoff. `RPCEndpointRotator` (actor) tracks per-endpoint failures with 5-min reset. Each client is a `struct` taking dependencies via initializer. Tests inject a `URLProtocol` mock that returns fixture data, so the production retry path is exercised end-to-end.

**Tech Stack:** Swift 5.9, async/await, Swift Testing, SwiftData, ImageIO/CoreGraphics, CryptoKit (SHA256), FeedKit (RSS/Atom parsing, locked to ^11.0.0).

**Reference:** `docs/superpowers/specs/2026-05-18-phase-1-data-layer-design.md`

---

## File Structure

```
Packages/SuiWidgetKit/
├── Package.swift                                # MODIFIED — adds FeedKit dep + Fixtures resource
└── Sources/SuiWidgetKit/
    ├── Models/
    │   ├── ActivityEvent.swift                  # NEW
    │   ├── AppSettings.swift                    # MODIFIED — singleton, timestamp fields
    │   ├── CachedCoinListEntry.swift            # NEW
    │   ├── CachedSuiNSResolution.swift          # NEW
    │   ├── CachedValidatorMetadata.swift        # NEW
    │   ├── NFTItem.swift                        # MODIFIED — unique objectId
    │   ├── NewsItem.swift                       # MODIFIED — NewsSource enum field
    │   ├── NewsSource.swift                     # NEW
    │   ├── Pet.swift                            # unchanged
    │   ├── PortfolioSnapshot.swift              # MODIFIED — cascade + unique id on CachedTokenHolding
    │   ├── Quest.swift                          # MODIFIED — QuestStatus enum
    │   ├── QuestStatus.swift                    # NEW
    │   ├── StakePosition.swift                  # MODIFIED — unique id + StakeStatus enum
    │   ├── StakeStatus.swift                    # NEW
    │   ├── SuiAddress.swift                     # NEW value type
    │   ├── TokenHolding.swift                   # unchanged
    │   └── Wallet.swift                         # unchanged
    ├── Networking/
    │   ├── CoinGeckoClient.swift                # REAL IMPL
    │   ├── CoinGeckoError.swift                 # NEW
    │   ├── CoinGeckoTypes.swift                 # NEW
    │   ├── HTTPClient.swift                     # NEW
    │   ├── HTTPClientError.swift                # NEW
    │   ├── IPFSGatewayResolver.swift            # NEW
    │   ├── ImageDownloader.swift                # NEW
    │   ├── ImagePipelineError.swift             # NEW
    │   ├── ImageResizer.swift                   # NEW
    │   ├── RPCEndpointRotator.swift             # REAL IMPL (actor)
    │   ├── RSSClient.swift                      # REAL IMPL
    │   ├── RSSError.swift                       # NEW
    │   ├── SuiRPCClient.swift                   # REAL IMPL
    │   ├── SuiRPCError.swift                    # NEW
    │   └── SuiRPCTypes.swift                    # NEW
    ├── Services/
    │   ├── NFTService.swift                     # REAL IMPL
    │   ├── NewsService.swift                    # REAL IMPL
    │   ├── PortfolioService.swift               # REAL IMPL
    │   ├── StakingService.swift                 # REAL IMPL
    │   ├── SuiNSError.swift                     # NEW
    │   ├── SuiNSResolver.swift                  # REAL IMPL
    │   └── WalletService.swift                  # REAL IMPL
    ├── Storage/
    │   ├── AppGroupStore.swift                  # MODIFIED — async API
    │   ├── ImageCache.swift                     # REAL IMPL (actor)
    │   ├── SwiftDataStack.swift                 # MODIFIED — populated schema
    │   └── ThumbnailGenerator.swift             # REAL IMPL
    └── Utilities/
        ├── Decimal+Crypto.swift                 # MODIFIED — real helpers
        └── URL+IPFS.swift                       # MODIFIED — real helpers
└── Tests/SuiWidgetKitTests/
    ├── AppGroupStoreTests.swift                 # MODIFIED — async
    ├── CoinGeckoClientTests.swift               # NEW
    ├── Fixtures/                                # NEW — ~20 JSON + binary files
    │   └── README.md                            # records wallet + curl commands used
    ├── Helpers/
    │   ├── FixtureLoader.swift                  # NEW
    │   ├── InjectableClock.swift                # NEW — test clock for rotator
    │   └── MockURLProtocol.swift                # NEW — stubs URLSession
    ├── HTTPClientTests.swift                    # NEW
    ├── ImagePipelineTests.swift                 # NEW
    ├── LiveIntegrationTests.swift               # NEW — .disabled()
    ├── NFTServiceTests.swift                    # NEW
    ├── NewsServiceTests.swift                   # NEW
    ├── PortfolioServiceTests.swift              # NEW
    ├── RPCEndpointRotatorTests.swift            # NEW
    ├── RSSClientTests.swift                     # NEW
    ├── StakingServiceTests.swift                # NEW
    ├── SuiAddressTests.swift                    # NEW
    ├── SuiNSResolverTests.swift                 # NEW
    ├── SuiRPCClientTests.swift                  # NEW
    └── WalletServiceTests.swift                 # NEW

SuiWidget/
├── App/
│   └── ContentView.swift                        # MODIFIED — await AppGroupStore
├── Widget/
│   └── Provider/TimelineProvider.swift          # MODIFIED — await AppGroupStore
.github/workflows/ci.yml                          # MODIFIED — needs: package-tests gate
CLAUDE.md                                         # MODIFIED — Quest.description → Quest.summary
README.md                                         # MODIFIED — Phase 1 capabilities
docs/superpowers/phase-1-prep.md                  # MODIFIED — mark resolved items
```

---

## Task 1: Phase 0 prep — enums, SuiAddress, model refactors

**Files:**
- Create: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/StakeStatus.swift`
- Create: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/QuestStatus.swift`
- Create: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NewsSource.swift`
- Create: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/SuiAddress.swift`
- Create: `Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/SuiAddressTests.swift`
- Modify: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/PortfolioSnapshot.swift`
- Modify: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/StakePosition.swift`
- Modify: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NewsItem.swift`
- Modify: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/AppSettings.swift`
- Modify: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NFTItem.swift`
- Modify: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Quest.swift`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Write `StakeStatus.swift`**

```swift
import Foundation

public enum StakeStatus: String, Codable, CaseIterable, Sendable {
    case active
    case pending
    case withdrawing
}
```

- [ ] **Step 2: Write `QuestStatus.swift`**

```swift
import Foundation

public enum QuestStatus: String, Codable, CaseIterable, Sendable {
    case available
    case inProgress = "in_progress"
    case completed
}
```

- [ ] **Step 3: Write `NewsSource.swift`**

```swift
import Foundation

public enum NewsSource: String, Codable, CaseIterable, Sendable {
    case blog
    case githubRelease = "github_release"
}
```

- [ ] **Step 4: Write `SuiAddress.swift`**

```swift
import Foundation

public struct SuiAddress: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        let lower = rawValue.lowercased()
        guard lower.hasPrefix("0x"), lower.count == 66 else { return nil }
        let hex = lower.dropFirst(2)
        let allowed: Set<Character> = Set("0123456789abcdef")
        guard hex.allSatisfy({ allowed.contains($0) }) else { return nil }
        self.rawValue = lower
    }

    public var description: String { rawValue }
}
```

- [ ] **Step 5: Write `SuiAddressTests.swift`**

```swift
import Testing
@testable import SuiWidgetKit

@Suite("SuiAddress")
struct SuiAddressTests {
    @Test func accepts_lowercase_64hex_with_0x_prefix() {
        let raw = "0x" + String(repeating: "a", count: 64)
        #expect(SuiAddress(rawValue: raw)?.rawValue == raw)
    }

    @Test func normalizes_mixed_case_to_lowercase() {
        let raw = "0x" + String(repeating: "A", count: 64)
        #expect(SuiAddress(rawValue: raw)?.rawValue == raw.lowercased())
    }

    @Test func rejects_missing_prefix() {
        let raw = String(repeating: "a", count: 64)
        #expect(SuiAddress(rawValue: raw) == nil)
    }

    @Test func rejects_wrong_length() {
        #expect(SuiAddress(rawValue: "0xab") == nil)
        #expect(SuiAddress(rawValue: "0x" + String(repeating: "a", count: 65)) == nil)
    }

    @Test func rejects_non_hex_characters() {
        let raw = "0x" + String(repeating: "g", count: 64)
        #expect(SuiAddress(rawValue: raw) == nil)
    }

    @Test func is_codable_round_trip() throws {
        let raw = "0x" + String(repeating: "a", count: 64)
        let address = SuiAddress(rawValue: raw)!
        let data = try JSONEncoder().encode(address)
        let decoded = try JSONDecoder().decode(SuiAddress.self, from: data)
        #expect(decoded == address)
    }
}
```

- [ ] **Step 6: Modify `PortfolioSnapshot.swift` — add cascade rules + unique id on CachedTokenHolding**

Replace the file contents with:

```swift
import Foundation
import SwiftData

/// Aggregate per-wallet portfolio snapshot.
@Model
public final class CachedPortfolio {
    @Attribute(.unique) public var walletId: UUID
    public var totalUSD: Decimal
    public var change24hUSD: Decimal
    public var change24hPercent: Double
    public var snapshotAt: Date
    @Relationship(deleteRule: .cascade) public var tokens: [CachedTokenHolding]
    @Relationship(deleteRule: .cascade) public var stakes: [CachedStakePosition]
    @Relationship(deleteRule: .cascade) public var nfts: [CachedNFTItem]

    public init(
        walletId: UUID,
        totalUSD: Decimal = 0,
        change24hUSD: Decimal = 0,
        change24hPercent: Double = 0,
        snapshotAt: Date = Date(),
        tokens: [CachedTokenHolding] = [],
        stakes: [CachedStakePosition] = [],
        nfts: [CachedNFTItem] = []
    ) {
        self.walletId = walletId
        self.totalUSD = totalUSD
        self.change24hUSD = change24hUSD
        self.change24hPercent = change24hPercent
        self.snapshotAt = snapshotAt
        self.tokens = tokens
        self.stakes = stakes
        self.nfts = nfts
    }
}

@Model
public final class CachedTokenHolding {
    @Attribute(.unique) public var id: UUID
    public var coinType: String
    public var symbol: String
    public var name: String
    public var balance: Decimal
    public var decimals: Int
    public var priceUSD: Decimal?
    public var priceChange24h: Double?
    public var iconURL: String?
    public var isTracked: Bool

    public init(
        id: UUID = UUID(),
        coinType: String,
        symbol: String,
        name: String,
        balance: Decimal,
        decimals: Int,
        priceUSD: Decimal? = nil,
        priceChange24h: Double? = nil,
        iconURL: String? = nil,
        isTracked: Bool
    ) {
        self.id = id
        self.coinType = coinType
        self.symbol = symbol
        self.name = name
        self.balance = balance
        self.decimals = decimals
        self.priceUSD = priceUSD
        self.priceChange24h = priceChange24h
        self.iconURL = iconURL
        self.isTracked = isTracked
    }
}
```

- [ ] **Step 7: Modify `StakePosition.swift` — unique id + StakeStatus enum**

Replace the file contents with:

```swift
import Foundation
import SwiftData

@Model
public final class CachedStakePosition {
    @Attribute(.unique) public var id: UUID
    public var validatorAddress: String
    public var validatorName: String?
    public var validatorImageURL: String?
    public var principal: Decimal
    public var estimatedReward: Decimal
    public var status: StakeStatus
    public var stakingPool: String

    public init(
        id: UUID = UUID(),
        validatorAddress: String,
        validatorName: String? = nil,
        validatorImageURL: String? = nil,
        principal: Decimal = 0,
        estimatedReward: Decimal = 0,
        status: StakeStatus,
        stakingPool: String
    ) {
        self.id = id
        self.validatorAddress = validatorAddress
        self.validatorName = validatorName
        self.validatorImageURL = validatorImageURL
        self.principal = principal
        self.estimatedReward = estimatedReward
        self.status = status
        self.stakingPool = stakingPool
    }
}
```

- [ ] **Step 8: Modify `NewsItem.swift` — NewsSource enum**

Replace with:

```swift
import Foundation
import SwiftData

@Model
public final class CachedNewsItem {
    @Attribute(.unique) public var id: String   // hash of URL
    public var title: String
    public var url: String
    public var publishedAt: Date
    public var source: NewsSource
    public var summary: String?

    public init(
        id: String,
        title: String,
        url: String,
        publishedAt: Date,
        source: NewsSource,
        summary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.source = source
        self.summary = summary
    }
}
```

- [ ] **Step 9: Modify `AppSettings.swift` — singleton key + timestamps**

Replace with:

```swift
import Foundation
import SwiftData

@Model
public final class AppSettings {
    @Attribute(.unique) public var singletonKey: String
    public var defaultCurrency: String
    public var theme: String
    public var refreshFrequencyMinutes: Int
    public var showUntrackedTokens: Bool
    public var notificationsEnabled: Bool
    public var lastCoinListFetchedAt: Date?
    public var lastNewsFetchedAt: Date?

    public init(
        singletonKey: String = "default",
        defaultCurrency: String = "USD",
        theme: String = "system",
        refreshFrequencyMinutes: Int = 30,
        showUntrackedTokens: Bool = true,
        notificationsEnabled: Bool = false,
        lastCoinListFetchedAt: Date? = nil,
        lastNewsFetchedAt: Date? = nil
    ) {
        self.singletonKey = singletonKey
        self.defaultCurrency = defaultCurrency
        self.theme = theme
        self.refreshFrequencyMinutes = refreshFrequencyMinutes
        self.showUntrackedTokens = showUntrackedTokens
        self.notificationsEnabled = notificationsEnabled
        self.lastCoinListFetchedAt = lastCoinListFetchedAt
        self.lastNewsFetchedAt = lastNewsFetchedAt
    }
}
```

- [ ] **Step 10: Modify `NFTItem.swift` — unique objectId**

Change the `public var objectId: String` line to `@Attribute(.unique) public var objectId: String` (no other changes).

- [ ] **Step 11: Modify `Quest.swift` — QuestStatus enum**

Replace the file contents with:

```swift
import Foundation
import SwiftData

/// V3 stub — quest entity. Not active in V1; never instantiated, never registered
/// in SwiftDataStack.schema. Reserved here so the file path is stable for V3.
@Model
public final class Quest {
    @Attribute(.unique) public var questId: String
    public var title: String
    public var summary: String
    public var xpReward: Int
    public var status: QuestStatus
    public var expiresAt: Date?

    public init(
        questId: String,
        title: String,
        summary: String,
        xpReward: Int,
        status: QuestStatus = .available,
        expiresAt: Date? = nil
    ) {
        self.questId = questId
        self.title = title
        self.summary = summary
        self.xpReward = xpReward
        self.status = status
        self.expiresAt = expiresAt
    }
}
```

- [ ] **Step 12: Update CLAUDE.md to match the renamed Quest field**

In `CLAUDE.md` find this block (around line 213):

```swift
@Model
final class Quest {
    @Attribute(.unique) var questId: String
    var title: String
    var description: String
    var xpReward: Int
    var status: String           // "available", "in_progress", "completed"
    var expiresAt: Date?
}
```

Replace with:

```swift
@Model
final class Quest {
    @Attribute(.unique) var questId: String
    var title: String
    var summary: String                 // renamed from description (avoids CustomStringConvertible shadow)
    var xpReward: Int
    var status: QuestStatus             // String-backed enum
    var expiresAt: Date?
}
```

- [ ] **Step 13: Build + test**

```bash
swift build --package-path Packages/SuiWidgetKit
swift test --package-path Packages/SuiWidgetKit
```
Expected: Build complete; all prior tests pass; new `SuiAddress` tests (6) pass.

- [ ] **Step 14: Commit**

```bash
git add Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/ \
        Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/SuiAddressTests.swift \
        CLAUDE.md
git commit -m "$(cat <<'EOF'
refactor(models): resolve Phase 0 deferred items before schema registration

- Add deleteRule: .cascade to CachedPortfolio relationships
- Add @Attribute(.unique) var id: UUID to CachedTokenHolding + CachedStakePosition
- Add singletonKey + lastCoinListFetchedAt + lastNewsFetchedAt to AppSettings
- Mark CachedNFTItem.objectId @Attribute(.unique)
- Introduce StakeStatus / QuestStatus / NewsSource string-backed enums and migrate
  the stringly-typed status fields to use them
- Introduce SuiAddress value type with validation
- Sync CLAUDE.md Quest model definition (description → summary, String → QuestStatus)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: AppGroupStore async migration

**Files:**
- Modify: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/AppGroupStore.swift`
- Modify: `Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/AppGroupStoreTests.swift`
- Modify: `SuiWidget/App/ContentView.swift`
- Modify: `SuiWidget/Widget/Provider/TimelineProvider.swift`

- [ ] **Step 1: Migrate `AppGroupStore.swift` to async**

Replace the `writeHandshake` and `readHandshake` methods (keep all other declarations identical):

```swift
public func writeHandshake(_ value: String) async throws {
    let url = handshakeURL
    let payload = HandshakePayload(value: value, writtenAt: Date())
    try await Task.detached(priority: .userInitiated) {
        let data = try JSONEncoder().encode(payload)
        try data.write(to: url, options: .atomic)
    }.value
}

public func readHandshake() async throws -> HandshakePayload? {
    let url = handshakeURL
    return try await Task.detached(priority: .userInitiated) { () -> HandshakePayload? in
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(HandshakePayload.self, from: data)
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return nil
        }
    }.value
}
```

- [ ] **Step 2: Update `AppGroupStoreTests.swift` to `async`**

Add `async` to each test function. Replace test bodies:

```swift
import Foundation
import Testing
@testable import SuiWidgetKit

@Suite("AppGroupStore")
struct AppGroupStoreTests {

    @Test("round-trips a handshake value through a file in the container")
    func roundTripsHandshakeValue() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        try await store.writeHandshake("test-value")

        let read = try await store.readHandshake()
        #expect(read?.value == "test-value")
    }

    @Test("returns nil when no handshake file has been written")
    func returnsNilWhenAbsent() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        #expect(try await store.readHandshake() == nil)
    }

    @Test("second write overwrites the first")
    func secondWriteOverwritesFirst() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        try await store.writeHandshake("first-value")
        try await store.writeHandshake("second-value")

        let read = try await store.readHandshake()
        #expect(read?.value == "second-value")
    }
}
```

- [ ] **Step 3: Update `ContentView.swift` writeAndReload to await**

Replace the `writeAndReload()` method body:

```swift
private func writeAndReload() {
    Task { @MainActor in
        do {
            let store = try AppGroupStore()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let value = "hello-\(timestamp)"
            let payload = HandshakePayload(value: value, writtenAt: Date())
            try await store.writeHandshake(value)
            lastWritten = payload
            lastRead = try await store.readHandshake()
            WidgetCenter.shared.reloadAllTimelines()
            errorMessage = nil
        } catch {
            errorMessage = "AppGroupStore error: \(error)"
        }
    }
}
```

- [ ] **Step 4: Update `TimelineProvider.swift` to bridge async via Task**

Replace `currentEntry()` and add an async helper:

```swift
import WidgetKit
import SuiWidgetKit

struct HandshakeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HandshakeEntry {
        HandshakeEntry(date: Date(), handshakeValue: "—")
    }

    func getSnapshot(in context: Context, completion: @escaping (HandshakeEntry) -> Void) {
        Task {
            let entry = await currentEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HandshakeEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            let nextRefresh = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func currentEntry() async -> HandshakeEntry {
        let value: String
        do {
            value = try await AppGroupStore().readHandshake()?.value ?? "(no value)"
        } catch {
            value = "(no value)"
        }
        return HandshakeEntry(date: Date(), handshakeValue: value)
    }
}
```

- [ ] **Step 5: Build the package + test**

```bash
swift build --package-path Packages/SuiWidgetKit
swift test --package-path Packages/SuiWidgetKit
```
Expected: 3 AppGroupStoreTests pass + 6 SuiAddressTests pass = 9 tests.

- [ ] **Step 6: Verify iOS build still succeeds**

```bash
xcodegen generate
xcodebuild build -project SuiWidget.xcodeproj -scheme SuiWidget \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/AppGroupStore.swift \
        Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/AppGroupStoreTests.swift \
        SuiWidget/App/ContentView.swift \
        SuiWidget/Widget/Provider/TimelineProvider.swift
git commit -m "$(cat <<'EOF'
refactor(kit): migrate AppGroupStore write/read to async throws

- Move file I/O off the calling actor via Task.detached(priority: .userInitiated)
- Update ContentView.writeAndReload to await both calls inside a Task
- Update HandshakeTimelineProvider to bridge async currentEntry() into the
  completion-handler-based TimelineProvider API
- All three AppGroupStoreTests cases converted to async

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tasks 3–13 — outline form

The remaining tasks follow the spec at `docs/superpowers/specs/2026-05-18-phase-1-data-layer-design.md` section-by-section. Each subagent dispatch will include the full task text synthesized from the spec; this outline captures the commit boundary and the spec section that defines the work.

### Task 3 — New SwiftData models
Files: `ActivityEvent.swift`, `CachedCoinListEntry.swift`, `CachedSuiNSResolution.swift`, `CachedValidatorMetadata.swift` + `ActivityEventKind` enum. Reference: spec §7. Commit: `feat(models): add new SwiftData entities for Phase 1 caches`.

### Task 4 — Schema registration
Modify `SwiftDataStack.swift` to populate the schema with all 13 model classes (alphabetical), plus a smoke test `SwiftDataStackTests.swift` that calls `makeContainer(inMemory: true)` and asserts no throw. Reference: spec §7 final section. Commit: `feat(kit): register all SwiftData models in SwiftDataStack.schema`.

### Task 5 — HTTPClient + retry + tests + helpers
Files: `HTTPClient.swift`, `HTTPClientError.swift`, `Helpers/MockURLProtocol.swift`, `Helpers/FixtureLoader.swift`, `HTTPClientTests.swift`. Tests: 429 retries with backoff, 5xx retries, 4xx no-retry, timeout retry, exhaustion error. Reference: spec §8. Commit: `feat(networking): add HTTPClient with exponential backoff retry`.

### Task 6 — RPCEndpointRotator (actor) + tests
Files: `RPCEndpointRotator.swift`, `Helpers/InjectableClock.swift`, `RPCEndpointRotatorTests.swift`. Tests: rotation on failure, 5-min reset window via injected clock, healthy endpoint preference. Reference: spec §8. Commit: `feat(networking): add RPCEndpointRotator actor with 5-min reset`.

### Task 7 — SuiRPCClient + types + fixture recording + tests
Files: `SuiRPCClient.swift`, `SuiRPCTypes.swift`, `SuiRPCError.swift`, fixture files in `Fixtures/`, `SuiRPCClientTests.swift`. Includes the live fixture-recording step (pick a public Mysten/Sui Foundation mainnet wallet, curl each method, commit raw responses). Tests replay fixtures via `MockURLProtocol`. Reference: spec §9. Commit: `feat(networking): add SuiRPCClient with seven RPC methods` + `chore(test): record Sui RPC fixtures for <walletAddress>`.

### Task 8 — CoinGeckoClient + types + fixtures + tests
Files: `CoinGeckoClient.swift`, `CoinGeckoTypes.swift`, `CoinGeckoError.swift`, fixtures, `CoinGeckoClientTests.swift`. Includes the 24h TTL check for coin list, the batched price endpoint, and the Sui-platform filter logic. Reference: spec §10. Commit: `feat(networking): add CoinGeckoClient with coin list + market prices`.

### Task 9 — FeedKit dep + RSSClient + fixtures + tests
Files: `Package.swift` (add FeedKit `^11.0.0`), `RSSClient.swift`, `RSSError.swift`, RSS/Atom fixtures, `RSSClientTests.swift`. Tests: parse blog RSS, parse Atom releases, merge + dedupe + sort + cap. Reference: spec §11. Commit: `feat(networking): add RSSClient with FeedKit for blog + releases feeds`.

### Task 10 — SuiNSResolver + tests
Files: `SuiNSResolver.swift`, `SuiNSError.swift`, `SuiNSResolverTests.swift`. Tests: `0x...` validation, `name.sui` resolve via fixture, `@name` normalization, cache hit skips network, reverse resolve. Reference: spec §12. Commit: `feat(services): add SuiNSResolver with 1h cache`.

### Task 11 — Image pipeline (5 files + tests)
Files: `IPFSGatewayResolver.swift`, `ImageDownloader.swift`, `ImageResizer.swift`, `ImagePipelineError.swift`, `ImageCache.swift` (full impl), `ThumbnailGenerator.swift` (full impl), `Utilities/URL+IPFS.swift` (real helpers), `Utilities/Decimal+Crypto.swift` (real helpers), `ImagePipelineTests.swift`. Tests use a hand-authored 16×16 PNG fixture; verify resize output dimensions; verify gateway rotation. Reference: spec §13. Commit: `feat(images): add download + IPFS rotation + ImageIO resize + App Group cache`.

### Task 12 — Services layer (5 services + tests)
Files: `WalletService.swift`, `PortfolioService.swift`, `NFTService.swift`, `StakingService.swift`, `NewsService.swift`, plus per-service tests (`WalletServiceTests`, `PortfolioServiceTests`, `NFTServiceTests`, `StakingServiceTests`, `NewsServiceTests`). Tests use prerecorded fixtures injected via `MockURLProtocol` so the production code paths are exercised end-to-end. Reference: spec §14. Commits: one per service (5 commits), each `feat(services): add <ServiceName>`.

### Task 13 — Live integration test + CI gate + docs
Files: `LiveIntegrationTests.swift` (disabled by default), `.github/workflows/ci.yml` (add `needs: package-tests` to `ios-build`), `Fixtures/README.md` (records wallet + curl commands), `README.md` (Phase 1 capabilities), `docs/superpowers/phase-1-prep.md` (mark items resolved). Live integration test asserts non-empty result from `PortfolioService.refreshAll(walletId:)` against the chosen mainnet wallet. Reference: spec §17, §18. Commit: `chore: add live integration test + CI gate + Phase 1 doc updates`.

---

## Acceptance

Final state: every spec §4 acceptance criterion satisfied. `swift test --package-path Packages/SuiWidgetKit` runs offline with all fixture-replay tests green. `swift test --filter "Live integration"` (when run manually) prints non-empty results for the test wallet. `xcodebuild build` for iOS Simulator continues to succeed. GitHub Actions CI green on both jobs with the new `needs:` gate.

## Self-review notes

- Type consistency: `SuiAddress`, `HTTPClient`, `HTTPClientError`, `RPCEndpointRotator`, `HandshakePayload`, `CachedPortfolio`, `CachedTokenHolding`, `CachedStakePosition`, `CachedNFTItem`, `CachedNewsItem`, `StakeStatus`, `QuestStatus`, `NewsSource`, `ActivityEvent`, `ActivityEventKind`, `CachedCoinListEntry`, `CachedValidatorMetadata`, `CachedSuiNSResolution`, `AppSettings`, `Wallet` — all referenced consistently across tasks and spec.
- Each task ends with a focused commit; no batching of unrelated work.
- Tests are written alongside (or before, for TDD-amenable units) implementation.
