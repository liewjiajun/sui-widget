# Phase 0 — Project Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the `sui-widget` repo so the iOS app + WidgetKit extension share `group.io.sui.widget`, a SwiftData stack is initialized with an empty schema, every file listed in CLAUDE.md "Project structure" exists as a compilable placeholder, and CI builds both `swift test` for the package and `xcodebuild build` for the iOS project.

**Architecture:** XcodeGen generates `SuiWidget.xcodeproj` from `project.yml`. App + widget extension are two iOS targets; both depend on a local Swift package `SuiWidgetKit` (`Packages/SuiWidgetKit/`). The package owns `AppGroupStore` (file I/O in the shared container) and `SwiftDataStack` (empty schema for now). Phase 0 ships an end-to-end visual handshake: the app writes a timestamped value to the App Group container, the widget reads it back on next timeline call. No real UI, no networking, no design system.

**Tech Stack:** Swift 5.9, iOS 17.0, SwiftUI, WidgetKit, SwiftData (empty), Swift Testing (unit), XCUITest (UI), XcodeGen (project generation), Homebrew, GitHub Actions (macos-15).

**Reference:** `docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md`

---

## File Structure

**Created in this plan** (paths relative to `/Users/liewjiajun/sui-widget/`):

```
.github/workflows/ci.yml                                  # CI for package + iOS build
.gitignore                                                 # Xcode + XcodeGen + SPM artifacts
README.md                                                  # bootstrap + acceptance recipe
project.yml                                                # XcodeGen — single source of truth

Packages/SuiWidgetKit/
├── Package.swift
├── Sources/SuiWidgetKit/
│   ├── Storage/
│   │   ├── AppGroupStore.swift                            # real impl + injectable for tests
│   │   ├── SwiftDataStack.swift                           # empty schema, group container
│   │   ├── ImageCache.swift                               # placeholder
│   │   └── ThumbnailGenerator.swift                       # placeholder
│   ├── Models/
│   │   ├── Wallet.swift, TokenHolding.swift,
│   │   │   PortfolioSnapshot.swift, StakePosition.swift,
│   │   │   NFTItem.swift, NewsItem.swift,
│   │   │   AppSettings.swift, Pet.swift, Quest.swift     # @Model stubs (not in schema)
│   ├── Networking/
│   │   ├── SuiRPCClient.swift, CoinGeckoClient.swift,
│   │   │   RSSClient.swift, RPCEndpointRotator.swift     # empty struct placeholders
│   ├── Services/
│   │   ├── WalletService.swift, PortfolioService.swift,
│   │   │   NFTService.swift, StakingService.swift,
│   │   │   NewsService.swift, SuiNSResolver.swift        # empty struct placeholders
│   └── Utilities/
│       ├── Decimal+Crypto.swift                          # empty extension
│       └── URL+IPFS.swift                                # empty extension
└── Tests/SuiWidgetKitTests/
    └── AppGroupStoreTests.swift                          # one round-trip test

SuiWidget/
├── App/
│   ├── SuiWidgetApp.swift                                # @main, mounts ContentView
│   ├── AppDelegate.swift                                 # placeholder (Phase 1 hosts BG tasks)
│   ├── ContentView.swift                                 # handshake UI (writes, reads, reloads widget)
│   └── Features/
│       ├── Onboarding/OnboardingView.swift
│       ├── WalletManagement/WalletListView.swift
│       ├── Portfolio/PortfolioView.swift
│       ├── NFTGallery/NFTGalleryView.swift
│       ├── News/NewsView.swift
│       ├── WidgetConfig/WidgetConfigView.swift
│       └── Settings/SettingsView.swift                   # all placeholder Views
├── Widget/
│   ├── SuiWidgetBundle.swift                             # @main WidgetBundle
│   ├── SuiWidgetWidget.swift                             # the real widget (handshake)
│   ├── Provider/
│   │   ├── TimelineProvider.swift                        # HandshakeTimelineProvider
│   │   └── WidgetEntry.swift                             # HandshakeEntry
│   ├── LockScreen/
│   │   ├── CircularWidgetView.swift, RectangularWidgetView.swift,
│   │   │   InlineWidgetView.swift                        # placeholder Views
│   └── HomeScreen/
│       ├── SmallWidgetView.swift, MediumWidgetView.swift,
│       │   LargeWidgetView.swift, ExtraLargeWidgetView.swift  # placeholder Views
├── Resources/
│   └── Assets.xcassets/                                  # AppIcon + AccentColor (empty)
├── Supporting/
│   ├── SuiWidget.entitlements                            # App Group
│   └── SuiWidgetWidget.entitlements                      # App Group
└── Tests/
    ├── SuiWidgetTests/PlaceholderTests.swift             # Swift Testing — one trivial test
    └── SuiWidgetUITests/PlaceholderUITests.swift         # XCUITest — one launch test
```

**Generated, gitignored:**
- `SuiWidget.xcodeproj/` (by `xcodegen generate`)
- `SuiWidget/Widget/Info.plist` (by `xcodegen generate`, populated from `project.yml` `info.properties`)
- `.build/`, `.swiftpm/`, `DerivedData/`

---

## Task 1: Verify environment + initialize repo

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `.git/` (via `git init`)

- [ ] **Step 1: Verify Xcode is the active developer tools (not Command Line Tools)**

Run: `xcode-select -p`
Expected: `/Applications/Xcode.app/Contents/Developer`

If output is `/Library/Developer/CommandLineTools`, **STOP** and ask the user to run:
```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

- [ ] **Step 2: Verify xcodebuild and an iOS Simulator runtime are available**

Run: `xcodebuild -version`
Expected: `Xcode 16.x` (or newer)

Run: `xcrun simctl list runtimes | grep -i ios`
Expected: at least one line like `iOS 17.x - com.apple.CoreSimulator.SimRuntime.iOS-17-...` or `iOS 18.x - ...`

If no iOS runtime is listed, **STOP** and ask the user to run `xcodebuild -downloadPlatform iOS` (takes several minutes), then resume.

- [ ] **Step 3: Install XcodeGen via Homebrew (skip if already installed)**

Run: `which xcodegen || brew install xcodegen`
Expected: Either path to existing binary, or successful install ending with `xcodegen` in `/opt/homebrew/bin/` or `/usr/local/bin/`.

Run: `xcodegen --version`
Expected: `Version: 2.x.x` (any 2.x version works)

- [ ] **Step 4: Initialize git repo**

Run from `/Users/liewjiajun/sui-widget/`:
```
git init
git branch -m main
```
Expected: `Initialized empty Git repository in /Users/liewjiajun/sui-widget/.git/`. Branch renamed to `main`.

- [ ] **Step 5: Write `.gitignore`**

Create `/Users/liewjiajun/sui-widget/.gitignore`:
```
# Xcode user state
*.xcuserstate
*.xcuserdatad
xcuserdata/
DerivedData/

# Generated by XcodeGen (project.yml is the source of truth)
SuiWidget.xcodeproj/
SuiWidget/Widget/Info.plist

# Swift Package Manager
.build/
.swiftpm/
Packages/*/.build/
Packages/*/.swiftpm/

# macOS
.DS_Store

# Misc
*.log
```

- [ ] **Step 6: Write `README.md`**

Create `/Users/liewjiajun/sui-widget/README.md`:
````markdown
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

## Repo layout

See [`docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md`](docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md) for the authoritative design.
````

- [ ] **Step 7: Initial commit (planning docs + tooling files)**

Run:
```
git add CLAUDE.md README.md .gitignore docs/
git commit -m "$(cat <<'EOF'
chore: initialize repo with planning docs and tooling

- CLAUDE.md technical brief (pre-existing)
- Phase 0 design spec and implementation plan under docs/superpowers/
- .gitignore for Xcode + XcodeGen + SPM artifacts
- README with bootstrap and acceptance instructions

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
Expected: Single commit on `main`, four/five top-level entries (`CLAUDE.md`, `README.md`, `.gitignore`, `docs/`).

Run: `git status` — should show "nothing to commit, working tree clean".

---

## Task 2: Swift package skeleton

**Files:**
- Create: `Packages/SuiWidgetKit/Package.swift`
- Create: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/SuiWidgetKit.swift`

- [ ] **Step 1: Create the package directories**

Run:
```
mkdir -p Packages/SuiWidgetKit/Sources/SuiWidgetKit
mkdir -p Packages/SuiWidgetKit/Tests/SuiWidgetKitTests
```

- [ ] **Step 2: Write `Packages/SuiWidgetKit/Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuiWidgetKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SuiWidgetKit", targets: ["SuiWidgetKit"]),
    ],
    targets: [
        .target(name: "SuiWidgetKit"),
        .testTarget(name: "SuiWidgetKitTests", dependencies: ["SuiWidgetKit"]),
    ]
)
```

- [ ] **Step 3: Write a stub module file so SwiftPM has something to compile**

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/SuiWidgetKit.swift`:
```swift
/// Public umbrella for the SuiWidgetKit module.
/// Real types live in subdirectories (Storage, Models, Networking, Services, Utilities).
public enum SuiWidgetKit {
    /// Semantic version of the SuiWidgetKit module. Phase 0 ships 0.0.1.
    public static let version = "0.0.1"
}
```

- [ ] **Step 4: Build the package**

Run: `swift build --package-path Packages/SuiWidgetKit`
Expected: `Build complete!` — no warnings, no errors.

- [ ] **Step 5: Commit**

```
git add Packages/SuiWidgetKit/
git commit -m "$(cat <<'EOF'
feat(kit): scaffold SuiWidgetKit Swift package

Empty umbrella module so SwiftPM can build and tests can run.
Real types follow in subsequent commits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: AppGroupStore (TDD)

**Files:**
- Create: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/AppGroupStore.swift`
- Create: `Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/AppGroupStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/AppGroupStoreTests.swift`:
```swift
import Foundation
import Testing
@testable import SuiWidgetKit

@Suite("AppGroupStore")
struct AppGroupStoreTests {

    @Test("round-trips a handshake value through a file in the container")
    func roundTripsHandshakeValue() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        try store.writeHandshake("test-value")

        let read = try store.readHandshake()
        #expect(read?.value == "test-value")
    }

    @Test("returns nil when no handshake file has been written")
    func returnsNilWhenAbsent() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        #expect(try store.readHandshake() == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails (type does not exist yet)**

Run: `swift test --package-path Packages/SuiWidgetKit`
Expected: Compilation error like `cannot find 'AppGroupStore' in scope` and/or `cannot find 'HandshakePayload' in scope`. **The build fails, not the test runs and fails — that's correct for this step.**

- [ ] **Step 3: Create the Storage directory and write the production implementation**

```
mkdir -p Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/AppGroupStore.swift`:
```swift
import Foundation

/// File-based shared store for values that must round-trip between the main
/// app and the widget extension via the `group.io.sui.widget` App Group container.
///
/// Phase 0 uses this for a single handshake value. Phase 1+ adds typed accessors
/// (cached portfolio JSON snapshot, last-refresh timestamp, etc.).
public struct AppGroupStore {

    /// The shared App Group identifier. Mirrored in the entitlement files for both targets.
    public static let groupIdentifier = "group.io.sui.widget"

    /// Filename of the handshake JSON inside the container.
    public static let handshakeFilename = "handshake.json"

    private let containerURL: URL

    /// Production initializer — uses the App Group container.
    /// Throws `AppGroupStoreError.containerUnavailable` when running outside an entitled target.
    public init() throws {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.groupIdentifier
        ) else {
            throw AppGroupStoreError.containerUnavailable
        }
        self.containerURL = url
    }

    /// Test initializer — uses an injected directory instead of the entitlement-backed container.
    public init(containerURL: URL) {
        self.containerURL = containerURL
    }

    /// Absolute URL of the handshake file inside the container.
    public var handshakeURL: URL {
        containerURL.appendingPathComponent(Self.handshakeFilename)
    }

    /// Writes a `HandshakePayload` containing `value` and the current timestamp.
    public func writeHandshake(_ value: String) throws {
        let payload = HandshakePayload(value: value, writtenAt: Date())
        let data = try JSONEncoder().encode(payload)
        try data.write(to: handshakeURL, options: .atomic)
    }

    /// Reads the most recent handshake payload, or `nil` if none has been written.
    public func readHandshake() throws -> HandshakePayload? {
        guard FileManager.default.fileExists(atPath: handshakeURL.path) else { return nil }
        let data = try Data(contentsOf: handshakeURL)
        return try JSONDecoder().decode(HandshakePayload.self, from: data)
    }
}

/// Serializable payload written by `AppGroupStore.writeHandshake(_:)`.
public struct HandshakePayload: Codable, Equatable {
    public let value: String
    public let writtenAt: Date

    public init(value: String, writtenAt: Date) {
        self.value = value
        self.writtenAt = writtenAt
    }
}

public enum AppGroupStoreError: Error {
    case containerUnavailable
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/SuiWidgetKit`
Expected: `Test Suite 'AppGroupStore' passed`, two passing tests. No warnings.

- [ ] **Step 5: Commit**

```
git add Packages/SuiWidgetKit/
git commit -m "$(cat <<'EOF'
feat(kit): add AppGroupStore for shared file I/O between app and widget

- Production init uses FileManager.containerURL with group.io.sui.widget
- Test init accepts an injected directory so swift test can run without entitlement
- Two Swift Testing cases: round-trip and absent-file
- HandshakePayload is Codable + Equatable for forthcoming snapshot usage

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: SwiftDataStack (empty schema, compile-only)

**Files:**
- Create: `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/SwiftDataStack.swift`

**Note on testing:** SwiftData's `ModelContainer` initialization from a CLI `swift test` context outside an entitled target is unreliable on macOS (it touches the file system in `~/Library/Application Support/...` and the group container path resolves to `nil`). This task uses **compile-only verification** — `swift build` confirms the API is used correctly; runtime verification happens in the in-simulator acceptance test (Task 13).

- [ ] **Step 1: Write `SwiftDataStack.swift`**

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/SwiftDataStack.swift`:
```swift
import Foundation
import SwiftData

/// Owns the shared `ModelContainer` used by both the main app and the widget extension.
///
/// Phase 0 ships with an empty schema. Phase 1 registers `Wallet`, `CachedPortfolio`,
/// `CachedTokenHolding`, `CachedStakePosition`, `CachedNFTItem`, `CachedNewsItem`,
/// and `AppSettings` here.
public enum SwiftDataStack {

    /// Currently empty. Add models in Phase 1 by listing them in this array.
    public static let schema = Schema([])

    /// Builds the `ModelContainer`. Production callers use the default (`inMemory: false`)
    /// to get the App Group-backed container. Test callers may pass `inMemory: true`
    /// to avoid touching the file system.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                "SuiWidget",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            configuration = ModelConfiguration(
                "SuiWidget",
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier("group.io.sui.widget")
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
```

- [ ] **Step 2: Build the package to confirm SwiftData API usage compiles**

Run: `swift build --package-path Packages/SuiWidgetKit`
Expected: `Build complete!` — no warnings, no errors. (If SwiftData reports "Schema cannot be empty" at *compile* time, see fallback below; this is a runtime check on real iOS, not compile-time.)

- [ ] **Step 3: Run the package tests to confirm no regressions**

Run: `swift test --package-path Packages/SuiWidgetKit`
Expected: Both AppGroupStoreTests pass; SwiftDataStack is unused at runtime so it stays compiled-but-untested.

- [ ] **Step 4: Commit**

```
git add Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/SwiftDataStack.swift
git commit -m "$(cat <<'EOF'
feat(kit): add SwiftDataStack with empty schema and App Group container

Empty Schema([]) for Phase 0; Phase 1 will register Wallet, CachedPortfolio,
CachedTokenHolding, CachedStakePosition, CachedNFTItem, CachedNewsItem, AppSettings.
makeContainer(inMemory:) returns the shared ModelContainer; in-memory mode skips
the group container so tests can build a container if needed in future phases.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Package placeholder files (Models, Networking, Services, Utilities, Storage stubs)

**Files (all created):**
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/ImageCache.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/ThumbnailGenerator.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Wallet.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/TokenHolding.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/PortfolioSnapshot.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/StakePosition.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NFTItem.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NewsItem.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/AppSettings.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Pet.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Quest.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/SuiRPCClient.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/CoinGeckoClient.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/RSSClient.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/RPCEndpointRotator.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/WalletService.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/PortfolioService.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/NFTService.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/StakingService.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/NewsService.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/SuiNSResolver.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Utilities/Decimal+Crypto.swift`
- `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Utilities/URL+IPFS.swift`

- [ ] **Step 1: Create the directories**

Run from `/Users/liewjiajun/sui-widget/`:
```
mkdir -p Packages/SuiWidgetKit/Sources/SuiWidgetKit/{Models,Networking,Services,Utilities}
```
(`Storage/` already exists from Task 3.)

- [ ] **Step 2: Write storage placeholders**

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/ImageCache.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: download → ImageIO resize (200×200 widget, 600×600 gallery)
/// → JPEG quality 0.8 → write to App Group container, file path stored on CachedNFTItem.
public struct ImageCache {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/ThumbnailGenerator.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: ImageIO-based resize used by `ImageCache`.
public struct ThumbnailGenerator {
    public init() {}
    // TODO: implement in Phase 1
}
```

- [ ] **Step 3: Write all `@Model` placeholders (Models/)**

Each file is the full SwiftData entity declaration per CLAUDE.md "Data models". None are registered in `SwiftDataStack.schema` yet — Phase 1 wires them in.

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Wallet.swift`:
```swift
import Foundation
import SwiftData

/// A Sui wallet the user is tracking. Not yet registered in SwiftDataStack.schema (Phase 1).
@Model
public final class Wallet {
    @Attribute(.unique) public var id: UUID
    public var address: String          // 0x-prefixed, 32 bytes
    public var label: String?
    public var suiNSName: String?
    public var addedAt: Date
    public var isPrimary: Bool
    public var orderIndex: Int

    public init(
        id: UUID = UUID(),
        address: String,
        label: String? = nil,
        suiNSName: String? = nil,
        addedAt: Date = Date(),
        isPrimary: Bool = false,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.address = address
        self.label = label
        self.suiNSName = suiNSName
        self.addedAt = addedAt
        self.isPrimary = isPrimary
        self.orderIndex = orderIndex
    }
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/TokenHolding.swift`:
```swift
import Foundation

/// Plain struct used by view models. The cached/persisted form is `CachedTokenHolding`
/// in `PortfolioSnapshot.swift`.
public struct TokenHolding: Codable, Equatable {
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

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/PortfolioSnapshot.swift`:
```swift
import Foundation
import SwiftData

/// Aggregate per-wallet portfolio snapshot. Not yet registered in SwiftDataStack.schema (Phase 1).
@Model
public final class CachedPortfolio {
    @Attribute(.unique) public var walletId: UUID
    public var totalUSD: Decimal
    public var change24hUSD: Decimal
    public var change24hPercent: Double
    public var snapshotAt: Date
    @Relationship public var tokens: [CachedTokenHolding]
    @Relationship public var stakes: [CachedStakePosition]
    @Relationship public var nfts: [CachedNFTItem]

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

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/StakePosition.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class CachedStakePosition {
    public var validatorAddress: String
    public var validatorName: String?
    public var validatorImageURL: String?
    public var principal: Decimal
    public var estimatedReward: Decimal
    public var status: String        // "active", "pending", "withdrawing"
    public var stakingPool: String

    public init(
        validatorAddress: String,
        validatorName: String? = nil,
        validatorImageURL: String? = nil,
        principal: Decimal = 0,
        estimatedReward: Decimal = 0,
        status: String,
        stakingPool: String
    ) {
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

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NFTItem.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class CachedNFTItem {
    public var objectId: String
    public var collectionName: String?
    public var name: String
    public var imageURL: String
    public var thumbnailFilePath: String?
    public var showInWidget: Bool
    public var attributes: [String: String]

    public init(
        objectId: String,
        collectionName: String? = nil,
        name: String,
        imageURL: String,
        thumbnailFilePath: String? = nil,
        showInWidget: Bool = false,
        attributes: [String: String] = [:]
    ) {
        self.objectId = objectId
        self.collectionName = collectionName
        self.name = name
        self.imageURL = imageURL
        self.thumbnailFilePath = thumbnailFilePath
        self.showInWidget = showInWidget
        self.attributes = attributes
    }
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/NewsItem.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class CachedNewsItem {
    @Attribute(.unique) public var id: String   // hash of URL
    public var title: String
    public var url: String
    public var publishedAt: Date
    public var source: String                    // "blog", "github_release"
    public var summary: String?

    public init(
        id: String,
        title: String,
        url: String,
        publishedAt: Date,
        source: String,
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

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/AppSettings.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class AppSettings {
    public var defaultCurrency: String
    public var theme: String
    public var refreshFrequencyMinutes: Int
    public var showUntrackedTokens: Bool
    public var notificationsEnabled: Bool

    public init(
        defaultCurrency: String = "USD",
        theme: String = "system",
        refreshFrequencyMinutes: Int = 30,
        showUntrackedTokens: Bool = true,
        notificationsEnabled: Bool = false
    ) {
        self.defaultCurrency = defaultCurrency
        self.theme = theme
        self.refreshFrequencyMinutes = refreshFrequencyMinutes
        self.showUntrackedTokens = showUntrackedTokens
        self.notificationsEnabled = notificationsEnabled
    }
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Pet.swift`:
```swift
import Foundation
import SwiftData

/// V2 stub — soul-bound pixel pet NFT. Not active in V1; never instantiated, never registered
/// in SwiftDataStack.schema. Reserved here so the file path is stable for V2.
@Model
public final class Pet {
    @Attribute(.unique) public var objectId: String
    public var walletAddress: String
    public var seed: String                      // keccak256(walletAddress + "::pet::v1")
    public var level: Int
    public var xp: Int
    public var traits: [String: String]
    public var spriteFilePath: String?
    public var hatchedAt: Date

    public init(
        objectId: String,
        walletAddress: String,
        seed: String,
        level: Int = 1,
        xp: Int = 0,
        traits: [String: String] = [:],
        spriteFilePath: String? = nil,
        hatchedAt: Date = Date()
    ) {
        self.objectId = objectId
        self.walletAddress = walletAddress
        self.seed = seed
        self.level = level
        self.xp = xp
        self.traits = traits
        self.spriteFilePath = spriteFilePath
        self.hatchedAt = hatchedAt
    }
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Models/Quest.swift`:
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
    public var status: String           // "available", "in_progress", "completed"
    public var expiresAt: Date?

    public init(
        questId: String,
        title: String,
        summary: String,
        xpReward: Int,
        status: String = "available",
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

- [ ] **Step 4: Write networking placeholders**

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/SuiRPCClient.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: JSON-RPC client for Mysten public + fallback endpoints,
/// with `RPCEndpointRotator` handling 429/5xx/timeout failover.
public struct SuiRPCClient {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/CoinGeckoClient.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: `/coins/list` (24h cache) + `/coins/markets` (5min cache).
public struct CoinGeckoClient {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/RSSClient.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: Sui blog RSS + GitHub releases Atom, merged and deduped.
public struct RSSClient {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Networking/RPCEndpointRotator.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: in-memory endpoint health tracking with 5-min reset.
public struct RPCEndpointRotator {
    public init() {}
    // TODO: implement in Phase 1
}
```

- [ ] **Step 5: Write services placeholders**

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/WalletService.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: add/list/edit/remove wallets via SwiftData.
public struct WalletService {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/PortfolioService.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: orchestrates SuiRPC + CoinGecko, computes 24h change.
public struct PortfolioService {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/NFTService.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: NFT enumeration + image pipeline trigger.
public struct NFTService {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/StakingService.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: fetches `suix_getStakes` + validator metadata.
public struct StakingService {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/NewsService.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: RSS fetch + merge + dedupe + 30-item cap.
public struct NewsService {
    public init() {}
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Services/SuiNSResolver.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: `name.sui` / `@name` / `0x...` resolution with 1h cache.
public struct SuiNSResolver {
    public init() {}
    // TODO: implement in Phase 1
}
```

- [ ] **Step 6: Write utility placeholders**

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Utilities/Decimal+Crypto.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: base-units ↔ display conversion, fixed-precision arithmetic.
public extension Decimal {
    // TODO: implement in Phase 1
}
```

Create `Packages/SuiWidgetKit/Sources/SuiWidgetKit/Utilities/URL+IPFS.swift`:
```swift
import Foundation

/// Placeholder. Phase 1 fills in: IPFS gateway rotation (`ipfs.io` → `cloudflare-ipfs.com` → `dweb.link`).
public extension URL {
    // TODO: implement in Phase 1
}
```

- [ ] **Step 7: Build + test the package**

Run: `swift build --package-path Packages/SuiWidgetKit`
Expected: `Build complete!` — no warnings, no errors.

Run: `swift test --package-path Packages/SuiWidgetKit`
Expected: Both AppGroupStoreTests still pass.

- [ ] **Step 8: Commit**

```
git add Packages/SuiWidgetKit/Sources/SuiWidgetKit/
git commit -m "$(cat <<'EOF'
chore(kit): scaffold placeholder files for all package subdirectories

- Models/: @Model declarations for Wallet, Cached* entities, AppSettings,
  plus V2 Pet and V3 Quest stubs. None registered in SwiftDataStack.schema yet.
- Networking/: empty SuiRPCClient, CoinGeckoClient, RSSClient, RPCEndpointRotator
- Services/: empty WalletService, PortfolioService, NFTService, StakingService,
  NewsService, SuiNSResolver
- Storage/: empty ImageCache, ThumbnailGenerator
- Utilities/: empty Decimal+Crypto, URL+IPFS

Every file compiles. None throw fatalError. Phase 1 fills in implementations.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Entitlements files

**Files:**
- Create: `SuiWidget/Supporting/SuiWidget.entitlements`
- Create: `SuiWidget/Supporting/SuiWidgetWidget.entitlements`

- [ ] **Step 1: Create the directory**

Run: `mkdir -p SuiWidget/Supporting`

- [ ] **Step 2: Write the app entitlements file**

Create `SuiWidget/Supporting/SuiWidget.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.io.sui.widget</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Write the widget entitlements file (identical content)**

Create `SuiWidget/Supporting/SuiWidgetWidget.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.io.sui.widget</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Sanity-check both files parse as valid plists**

Run: `plutil -lint SuiWidget/Supporting/SuiWidget.entitlements SuiWidget/Supporting/SuiWidgetWidget.entitlements`
Expected: Both lines say `OK`.

- [ ] **Step 5: Commit**

```
git add SuiWidget/Supporting/
git commit -m "$(cat <<'EOF'
feat(targets): add App Group entitlements for app and widget extension

Both files grant access to group.io.sui.widget, the shared container used by
AppGroupStore to round-trip handshake values and (Phase 1+) cached snapshots.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: App target — entry point + handshake UI + Feature placeholders

**Files:**
- Create: `SuiWidget/App/SuiWidgetApp.swift`
- Create: `SuiWidget/App/AppDelegate.swift`
- Create: `SuiWidget/App/ContentView.swift`
- Create: `SuiWidget/App/Features/Onboarding/OnboardingView.swift`
- Create: `SuiWidget/App/Features/WalletManagement/WalletListView.swift`
- Create: `SuiWidget/App/Features/Portfolio/PortfolioView.swift`
- Create: `SuiWidget/App/Features/NFTGallery/NFTGalleryView.swift`
- Create: `SuiWidget/App/Features/News/NewsView.swift`
- Create: `SuiWidget/App/Features/WidgetConfig/WidgetConfigView.swift`
- Create: `SuiWidget/App/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Create the directories**

```
mkdir -p SuiWidget/App/Features/{Onboarding,WalletManagement,Portfolio,NFTGallery,News,WidgetConfig,Settings}
```

- [ ] **Step 2: Write `SuiWidgetApp.swift`**

Create `SuiWidget/App/SuiWidgetApp.swift`:
```swift
import SwiftUI

@main
struct SuiWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 3: Write `AppDelegate.swift` (placeholder)**

Create `SuiWidget/App/AppDelegate.swift`:
```swift
import UIKit

/// Placeholder. Phase 1 will host BGTaskScheduler registration for:
/// - io.sui.widget.refresh (BGAppRefreshTask, 30 min)
/// - io.sui.widget.cleanup (BGProcessingTask, weekly)
/// - io.sui.widget.coinlist (BGAppRefreshTask, daily)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // TODO: register background tasks in Phase 1
        return true
    }
}
```

- [ ] **Step 4: Write `ContentView.swift` — the handshake UI**

Create `SuiWidget/App/ContentView.swift`:
```swift
import SwiftUI
import SuiWidgetKit
import WidgetKit

struct ContentView: View {
    @State private var lastWritten: HandshakePayload?
    @State private var lastRead: HandshakePayload?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("App Group handshake")
                .font(.headline)

            row(label: "Wrote:", payload: lastWritten)
            row(label: "Read back:", payload: lastRead)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            }

            Button("Write again", action: writeAndReload)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { writeAndReload() }
    }

    @ViewBuilder
    private func row(label: String, payload: HandshakePayload?) -> some View {
        HStack(alignment: .top) {
            Text(label).bold()
            Text(payload?.value ?? "—")
                .monospaced()
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }

    private func writeAndReload() {
        do {
            let store = try AppGroupStore()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let value = "hello-\(timestamp)"
            try store.writeHandshake(value)
            lastWritten = try store.readHandshake()
            lastRead = lastWritten
            WidgetCenter.shared.reloadAllTimelines()
            errorMessage = nil
        } catch {
            errorMessage = "AppGroupStore error: \(error)"
        }
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 5: Write the seven Feature placeholders**

Each file is the same shape: a `View`-conforming struct with a single `Text("TODO: <Name>")` body.

Create `SuiWidget/App/Features/Onboarding/OnboardingView.swift`:
```swift
import SwiftUI

/// Placeholder. Phase 2 fills in the onboarding flow per the Figma design.
struct OnboardingView: View {
    var body: some View {
        Text("TODO: OnboardingView")
    }
}
```

Create `SuiWidget/App/Features/WalletManagement/WalletListView.swift`:
```swift
import SwiftUI

/// Placeholder. Phase 2 fills in add/list/edit/remove wallet UI per the Figma design.
struct WalletListView: View {
    var body: some View {
        Text("TODO: WalletListView")
    }
}
```

Create `SuiWidget/App/Features/Portfolio/PortfolioView.swift`:
```swift
import SwiftUI

/// Placeholder. Phase 2 fills in aggregate + per-wallet portfolio view per the Figma design.
struct PortfolioView: View {
    var body: some View {
        Text("TODO: PortfolioView")
    }
}
```

Create `SuiWidget/App/Features/NFTGallery/NFTGalleryView.swift`:
```swift
import SwiftUI

/// Placeholder. Phase 2 fills in NFT gallery with show-in-widget toggle per the Figma design.
struct NFTGalleryView: View {
    var body: some View {
        Text("TODO: NFTGalleryView")
    }
}
```

Create `SuiWidget/App/Features/News/NewsView.swift`:
```swift
import SwiftUI

/// Placeholder. Phase 2 fills in news feed with in-app browser per the Figma design.
struct NewsView: View {
    var body: some View {
        Text("TODO: NewsView")
    }
}
```

Create `SuiWidget/App/Features/WidgetConfig/WidgetConfigView.swift`:
```swift
import SwiftUI

/// Placeholder. Phase 3 fills in the widget configurator UI per the Figma design.
struct WidgetConfigView: View {
    var body: some View {
        Text("TODO: WidgetConfigView")
    }
}
```

Create `SuiWidget/App/Features/Settings/SettingsView.swift`:
```swift
import SwiftUI

/// Placeholder. Phase 2 fills in settings per the Figma design.
struct SettingsView: View {
    var body: some View {
        Text("TODO: SettingsView")
    }
}
```

- [ ] **Step 6: Commit (app target sources only — does not build yet without project.yml)**

```
git add SuiWidget/App/
git commit -m "$(cat <<'EOF'
feat(app): scaffold main app target sources

- SuiWidgetApp: @main entry mounting ContentView
- ContentView: handshake UI that writes ISO-8601 value via AppGroupStore,
  reads it back, and triggers WidgetCenter.reloadAllTimelines()
- AppDelegate: placeholder; Phase 1 registers BGTaskScheduler identifiers
- Features/*: placeholder Views for Onboarding, WalletManagement, Portfolio,
  NFTGallery, News, WidgetConfig, Settings

App target won't build standalone until Task 10 runs xcodegen.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Widget target — bundle + real widget + provider + placeholders

**Files:**
- Create: `SuiWidget/Widget/SuiWidgetBundle.swift`
- Create: `SuiWidget/Widget/SuiWidgetWidget.swift`
- Create: `SuiWidget/Widget/Provider/TimelineProvider.swift`
- Create: `SuiWidget/Widget/Provider/WidgetEntry.swift`
- Create: `SuiWidget/Widget/LockScreen/CircularWidgetView.swift`
- Create: `SuiWidget/Widget/LockScreen/RectangularWidgetView.swift`
- Create: `SuiWidget/Widget/LockScreen/InlineWidgetView.swift`
- Create: `SuiWidget/Widget/HomeScreen/SmallWidgetView.swift`
- Create: `SuiWidget/Widget/HomeScreen/MediumWidgetView.swift`
- Create: `SuiWidget/Widget/HomeScreen/LargeWidgetView.swift`
- Create: `SuiWidget/Widget/HomeScreen/ExtraLargeWidgetView.swift`

- [ ] **Step 1: Create the directories**

```
mkdir -p SuiWidget/Widget/{Provider,LockScreen,HomeScreen}
```

- [ ] **Step 2: Write `SuiWidgetBundle.swift`**

Create `SuiWidget/Widget/SuiWidgetBundle.swift`:
```swift
import WidgetKit
import SwiftUI

@main
struct SuiWidgetBundle: WidgetBundle {
    var body: some Widget {
        SuiWidgetWidget()
    }
}
```

- [ ] **Step 3: Write `SuiWidgetWidget.swift` — the real widget**

Create `SuiWidget/Widget/SuiWidgetWidget.swift`:
```swift
import WidgetKit
import SwiftUI
import SuiWidgetKit

struct SuiWidgetWidget: Widget {
    let kind = "SuiWidgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HandshakeTimelineProvider()) { entry in
            HandshakeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sui Handshake")
        .description("Phase 0 placeholder — shows the value written by the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct HandshakeWidgetView: View {
    let entry: HandshakeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sui Widget")
                .font(.caption)
                .bold()
            Text(entry.handshakeValue)
                .font(.caption2)
                .monospaced()
                .lineLimit(3)
            Spacer()
            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

- [ ] **Step 4: Write `Provider/TimelineProvider.swift`**

Create `SuiWidget/Widget/Provider/TimelineProvider.swift`:
```swift
import WidgetKit
import SuiWidgetKit

struct HandshakeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HandshakeEntry {
        HandshakeEntry(date: Date(), handshakeValue: "—")
    }

    func getSnapshot(in context: Context, completion: @escaping (HandshakeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HandshakeEntry>) -> Void) {
        let entry = currentEntry()
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> HandshakeEntry {
        let value = (try? AppGroupStore().readHandshake()?.value) ?? "(no value)"
        return HandshakeEntry(date: Date(), handshakeValue: value)
    }
}
```

- [ ] **Step 5: Write `Provider/WidgetEntry.swift`**

Create `SuiWidget/Widget/Provider/WidgetEntry.swift`:
```swift
import WidgetKit

struct HandshakeEntry: TimelineEntry {
    let date: Date
    let handshakeValue: String
}
```

- [ ] **Step 6: Write the seven widget-view placeholders**

Each file is a `View` struct with `Text("TODO: <Name>")`. None are wired into `SuiWidgetWidget` yet — Phase 3 plumbs them into a configurable widget.

Create `SuiWidget/Widget/LockScreen/CircularWidgetView.swift`:
```swift
import SwiftUI
import WidgetKit

/// Placeholder. Phase 3 fills in the .accessoryCircular Lock Screen view.
struct CircularWidgetView: View {
    var body: some View {
        Text("TODO: CircularWidgetView")
    }
}
```

Create `SuiWidget/Widget/LockScreen/RectangularWidgetView.swift`:
```swift
import SwiftUI
import WidgetKit

/// Placeholder. Phase 3 fills in the .accessoryRectangular Lock Screen view.
struct RectangularWidgetView: View {
    var body: some View {
        Text("TODO: RectangularWidgetView")
    }
}
```

Create `SuiWidget/Widget/LockScreen/InlineWidgetView.swift`:
```swift
import SwiftUI
import WidgetKit

/// Placeholder. Phase 3 fills in the .accessoryInline Lock Screen view.
struct InlineWidgetView: View {
    var body: some View {
        Text("TODO: InlineWidgetView")
    }
}
```

Create `SuiWidget/Widget/HomeScreen/SmallWidgetView.swift`:
```swift
import SwiftUI
import WidgetKit

/// Placeholder. Phase 3 fills in the .systemSmall Home Screen view.
struct SmallWidgetView: View {
    var body: some View {
        Text("TODO: SmallWidgetView")
    }
}
```

Create `SuiWidget/Widget/HomeScreen/MediumWidgetView.swift`:
```swift
import SwiftUI
import WidgetKit

/// Placeholder. Phase 3 fills in the .systemMedium Home Screen view.
struct MediumWidgetView: View {
    var body: some View {
        Text("TODO: MediumWidgetView")
    }
}
```

Create `SuiWidget/Widget/HomeScreen/LargeWidgetView.swift`:
```swift
import SwiftUI
import WidgetKit

/// Placeholder. Phase 3 fills in the .systemLarge Home Screen view.
struct LargeWidgetView: View {
    var body: some View {
        Text("TODO: LargeWidgetView")
    }
}
```

Create `SuiWidget/Widget/HomeScreen/ExtraLargeWidgetView.swift`:
```swift
import SwiftUI
import WidgetKit

/// Placeholder. Phase 3 fills in the .systemExtraLarge Home Screen view.
struct ExtraLargeWidgetView: View {
    var body: some View {
        Text("TODO: ExtraLargeWidgetView")
    }
}
```

- [ ] **Step 7: Commit**

```
git add SuiWidget/Widget/
git commit -m "$(cat <<'EOF'
feat(widget): scaffold widget extension target sources

- SuiWidgetBundle: @main WidgetBundle entry point
- SuiWidgetWidget: real handshake widget showing the value AppGroupStore read
- HandshakeTimelineProvider: reads handshake on each timeline call,
  schedules next refresh 30 min out
- HandshakeEntry: TimelineEntry with date + handshakeValue
- LockScreen/ and HomeScreen/ View placeholders for Phase 3

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Resources — Assets.xcassets + Tests directory + test placeholders

**Files:**
- Create: `SuiWidget/Resources/Assets.xcassets/Contents.json`
- Create: `SuiWidget/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `SuiWidget/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `SuiWidget/Tests/SuiWidgetTests/PlaceholderTests.swift`
- Create: `SuiWidget/Tests/SuiWidgetUITests/PlaceholderUITests.swift`

- [ ] **Step 1: Create the directories**

```
mkdir -p SuiWidget/Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p SuiWidget/Resources/Assets.xcassets/AccentColor.colorset
mkdir -p SuiWidget/Tests/SuiWidgetTests
mkdir -p SuiWidget/Tests/SuiWidgetUITests
```

- [ ] **Step 2: Write the asset catalog index `Contents.json`**

Create `SuiWidget/Resources/Assets.xcassets/Contents.json`:
```json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

- [ ] **Step 3: Write the empty AppIcon set**

Create `SuiWidget/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images": [
    {
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

- [ ] **Step 4: Write the empty AccentColor set**

Create `SuiWidget/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors": [
    {
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

- [ ] **Step 5: Write the app unit-test placeholder**

Create `SuiWidget/Tests/SuiWidgetTests/PlaceholderTests.swift`:
```swift
import Testing
@testable import SuiWidget

@Suite("Placeholder")
struct PlaceholderTests {
    @Test("the placeholder test exists so the test target builds and runs")
    func placeholder() {
        #expect(2 + 2 == 4)
    }
}
```

- [ ] **Step 6: Write the UI test placeholder**

Create `SuiWidget/Tests/SuiWidgetUITests/PlaceholderUITests.swift`:
```swift
import XCTest

final class PlaceholderUITests: XCTestCase {
    func test_appLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["App Group handshake"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 7: Commit**

```
git add SuiWidget/Resources/ SuiWidget/Tests/
git commit -m "$(cat <<'EOF'
chore(targets): scaffold Assets.xcassets and test target placeholders

- Empty AppIcon and AccentColor sets (filled in Phase 2 with Figma design)
- PlaceholderTests: Swift Testing case so SuiWidgetTests target builds
- PlaceholderUITests: XCUITest launching the app and asserting the
  handshake header is visible — exercises the in-simulator acceptance path

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: XcodeGen `project.yml` + first generate

**Files:**
- Create: `project.yml`
- Generated (gitignored): `SuiWidget.xcodeproj/`, `SuiWidget/Widget/Info.plist`

- [ ] **Step 1: Write `project.yml`**

Create `/Users/liewjiajun/sui-widget/project.yml`:
```yaml
name: SuiWidget
options:
  bundleIdPrefix: io.sui.widget
  deploymentTarget:
    iOS: "17.0"
  developmentLanguage: en
  createIntermediateGroups: true
  generateEmptyDirectories: true
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.9"
    CODE_SIGN_STYLE: Automatic
    DEVELOPMENT_TEAM: ""
    ENABLE_USER_SCRIPT_SANDBOXING: YES

packages:
  SuiWidgetKit:
    path: Packages/SuiWidgetKit

targets:
  SuiWidget:
    type: application
    platform: iOS
    sources:
      - path: SuiWidget/App
      - path: SuiWidget/Resources
    dependencies:
      - target: SuiWidgetWidget
      - package: SuiWidgetKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.sui.widget
        CODE_SIGN_ENTITLEMENTS: SuiWidget/Supporting/SuiWidget.entitlements
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_CFBundleDisplayName: Sui Widget

  SuiWidgetWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: SuiWidget/Widget
    dependencies:
      - package: SuiWidgetKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.sui.widget.WidgetExtension
        CODE_SIGN_ENTITLEMENTS: SuiWidget/Supporting/SuiWidgetWidget.entitlements
        GENERATE_INFOPLIST_FILE: NO
    info:
      path: SuiWidget/Widget/Info.plist
      properties:
        CFBundleDisplayName: Sui Widget
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension

  SuiWidgetTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: SuiWidget/Tests/SuiWidgetTests
    dependencies:
      - target: SuiWidget

  SuiWidgetUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: SuiWidget/Tests/SuiWidgetUITests
    dependencies:
      - target: SuiWidget

schemes:
  SuiWidget:
    build:
      targets:
        SuiWidget: all
        SuiWidgetWidget: all
    test:
      targets:
        - SuiWidgetTests
        - SuiWidgetUITests
    run:
      executable: SuiWidget
```

- [ ] **Step 2: Generate the Xcode project**

Run from `/Users/liewjiajun/sui-widget/`: `xcodegen generate`
Expected: `Generated project successfully.` Output mentions writing `SuiWidget.xcodeproj` and `SuiWidget/Widget/Info.plist`.

- [ ] **Step 3: Verify the project file exists and schemes are correct**

Run: `xcodebuild -list -project SuiWidget.xcodeproj`
Expected output includes:
```
Targets:
    SuiWidget
    SuiWidgetTests
    SuiWidgetUITests
    SuiWidgetWidget

Schemes:
    SuiWidget
```

- [ ] **Step 4: Verify the widget Info.plist was generated correctly**

Run: `plutil -p SuiWidget/Widget/Info.plist`
Expected output includes:
```
"CFBundleDisplayName" => "Sui Widget"
"NSExtension" => {
  "NSExtensionPointIdentifier" => "com.apple.widgetkit-extension"
}
```

- [ ] **Step 5: Confirm `SuiWidget.xcodeproj/` and `SuiWidget/Widget/Info.plist` are gitignored**

Run: `git status`
Expected: Only `project.yml` shows as untracked. Neither `SuiWidget.xcodeproj/` nor `SuiWidget/Widget/Info.plist` should appear. (If either appears, double-check the `.gitignore` from Task 1.)

- [ ] **Step 6: Commit `project.yml`**

```
git add project.yml
git commit -m "$(cat <<'EOF'
build: add XcodeGen project.yml as the single source of truth

Defines the SuiWidget application target, SuiWidgetWidget app-extension target,
SuiWidgetTests unit-test target, and SuiWidgetUITests UI-test target. App and
widget both depend on the local SuiWidgetKit Swift package. Bundle IDs are
io.sui.widget and io.sui.widget.WidgetExtension; signing is automatic with
no team committed. The generated .xcodeproj and widget Info.plist are gitignored.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: xcodebuild verification (no signing)

**Files:** none new — runtime verification only.

- [ ] **Step 1: Build the SuiWidget scheme for an iOS Simulator destination**

Run from `/Users/liewjiajun/sui-widget/`:
```
xcodebuild build \
  -project SuiWidget.xcodeproj \
  -scheme SuiWidget \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
```
Expected: Last line is `** BUILD SUCCEEDED **`. Both `SuiWidget.app` and the embedded `SuiWidgetWidget.appex` are linked.

If the build fails with a SwiftData ModelContainer error referencing groupContainer, this is the deferred-Phase-1 case discussed in Task 4 — SwiftDataStack is not exercised by Phase 0's handshake, so the failure can only come from compile-time API misuse. Re-verify Task 4 step 1 file contents.

- [ ] **Step 2: Confirm both products were produced**

Run: `find ~/Library/Developer/Xcode/DerivedData -name "SuiWidget.app" -type d 2>/dev/null | head -3`
Expected: A path under `.../Build/Products/Debug-iphonesimulator/SuiWidget.app`.

Run: `find ~/Library/Developer/Xcode/DerivedData -name "SuiWidgetWidget.appex" -type d 2>/dev/null | head -3`
Expected: A path under `.../Build/Products/Debug-iphonesimulator/SuiWidget.app/PlugIns/SuiWidgetWidget.appex`. (The widget is embedded inside the app bundle's `PlugIns/` directory.)

- [ ] **Step 3: No commit** — this task is verification only.

---

## Task 12: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create the workflows directory**

Run: `mkdir -p .github/workflows`

- [ ] **Step 2: Write `.github/workflows/ci.yml`**

Create `/Users/liewjiajun/sui-widget/.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  package-tests:
    name: SuiWidgetKit unit tests
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Print Swift version
        run: swift --version
      - name: Run swift test
        run: swift test --package-path Packages/SuiWidgetKit

  ios-build:
    name: iOS app + widget build
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Print Xcode version
        run: xcodebuild -version
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: Build app + widget
        run: |
          set -o pipefail
          xcodebuild build \
            -project SuiWidget.xcodeproj \
            -scheme SuiWidget \
            -destination 'generic/platform=iOS Simulator' \
            -configuration Debug \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY=""
```

- [ ] **Step 3: Validate the workflow YAML parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`
Expected: No output, exit code 0.

(If Python is unavailable, fall back to `xcodegen generate` — XcodeGen ships a YAML parser; any malformed YAML in the same Ruby would surface here. Skip this if neither works; GitHub will surface YAML errors on push.)

- [ ] **Step 4: Commit**

```
git add .github/
git commit -m "$(cat <<'EOF'
ci: add GitHub Actions workflow for package tests and iOS build

Two jobs on macos-15:
- package-tests: swift test --package-path Packages/SuiWidgetKit
- ios-build: brew install xcodegen, xcodegen generate, xcodebuild build
  for a generic iOS Simulator destination with code signing disabled

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: In-simulator acceptance test (manual handoff)

**Files:** none — this is a human verification step that I drive together with the user.

This task **cannot be fully automated** because the simulator needs a logged-in Apple Developer team for the App Group entitlement to work, and adding the widget to the Home Screen requires direct simulator interaction.

- [ ] **Step 1: Open the project in Xcode**

Run: `open SuiWidget.xcodeproj`
Expected: Xcode launches and opens the project.

- [ ] **Step 2: Pick a Development Team on both targets**

In Xcode:
1. Select the project node in the navigator.
2. For target **SuiWidget** → Signing & Capabilities → set "Team" to your personal team (or any team you have access to).
3. For target **SuiWidgetWidget** → Signing & Capabilities → set the same team.
4. Confirm "App Groups" capability lists `group.io.sui.widget` for both targets (it should — driven by the entitlements files).

- [ ] **Step 3: Build and run on iPhone simulator**

In Xcode:
1. Select an iPhone simulator destination (e.g., "iPhone 16" or "iPhone 17" — whatever is installed).
2. Press ⌘R or click Run.
3. Wait for the simulator to boot and the app to launch.

Expected: The app displays:
```
App Group handshake
Wrote:       hello-2026-05-17T...
Read back:   hello-2026-05-17T...
[Write again]
```
The "Wrote" and "Read back" values should be identical.

If the **errorMessage** label appears in red saying "AppGroupStore error: containerUnavailable", the entitlement is not in effect — re-check step 2 of this task.

- [ ] **Step 4: Add the widget to the Home Screen**

In the simulator:
1. Press ⌘⇧H to go to the Home Screen.
2. Long-press the Home Screen background → tap the **+** button in the top-left.
3. Search for "Sui" → find the "Sui Handshake" widget → tap "Add Widget" → place a small or medium variant.

Expected: The widget displays:
```
Sui Widget
hello-2026-05-17T...
HH:MM
```
The handshake value matches the one shown in the app.

- [ ] **Step 5: Round-trip a new value**

1. Switch back to the SuiWidget app in the simulator.
2. Tap **Write again**.
3. The app's "Wrote" and "Read back" values update to a new timestamp.
4. In Xcode menu: **Debug → Refresh Widget Timelines** (or wait up to 30 min for the system to honor the `WidgetCenter.reloadAllTimelines()` call).
5. The widget on the Home Screen updates to display the new value.

Expected: App and widget show the same updated value. Acceptance criterion 4 in the spec is satisfied.

- [ ] **Step 6: Push to GitHub and verify CI**

If a GitHub remote isn't already set up:
1. (User action) Create a private GitHub repo named `sui-widget` (or whatever the user prefers).
2. Run: `git remote add origin git@github.com:<username>/sui-widget.git`
3. Run: `git push -u origin main`
4. Open the Actions tab in GitHub and confirm both `package-tests` and `ios-build` jobs go green.

If a remote already exists, just `git push` and watch CI.

- [ ] **Step 7: No commit** — Phase 0 is complete when steps 1–6 all pass.

---

## Self-Review Pass

After all tasks complete, verify:

1. **Spec coverage** — every acceptance criterion in `docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md` section 4 is covered:
   - AC1 (xcodegen produces .xcodeproj) → Task 10 step 2
   - AC2 (SuiWidget scheme builds, no warnings) → Task 11
   - AC3 (in-sim app shows handshake) → Task 13 step 3
   - AC4 (widget shows handshake, updates) → Task 13 steps 4–5
   - AC5 (swift test passes) → Task 3 step 4, Task 4 step 3, Task 5 step 7
   - AC6 (CI is green) → Task 13 step 6

2. **Files vs spec section 6** — every file listed in the spec's "Project structure" / "Files (all created)" exists. Spot-check by running `find SuiWidget Packages -name "*.swift" | wc -l` and confirm it matches expectations (~40 files).

3. **No regressions in placeholders** — `grep -r "fatalError\|TBD\|FIXME" SuiWidget Packages` should return only the intentional `// TODO: implement in Phase 1` comments documented in the spec.

---

## Notes for Phase 1+

These items are deliberately deferred:

- Real models registered in `SwiftDataStack.schema`
- Networking clients populated
- IPFS gateway rotation, ImageIO resize, thumbnail storage
- BGTaskScheduler registration + Info.plist `BGTaskSchedulerPermittedIdentifiers`
- Design system / Figma import (waiting on user-supplied designs)
- Localization strings catalog
- Snapshot tests for widget rendering
- Lock Screen widgets wired into `SuiWidgetWidget` configuration
- Deep link URL scheme (`suiwidget://`)
