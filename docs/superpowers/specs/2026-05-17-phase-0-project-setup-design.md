# Phase 0 — Project Setup Design

**Status:** Approved 2026-05-17
**Scope:** CLAUDE.md "Phase 0: Project setup (Week 1)" only
**Implements:** Repo bootstrap, Xcode project + widget extension + Swift package, App Group entitlement, SwiftData stack (empty), GitHub Actions CI, scaffold of every file listed in CLAUDE.md "Project structure"

## 1. Context

Sui Widget is a free, native iOS app that displays a Sui user's portfolio, NFTs, staking positions, and ecosystem news on Home Screen and Lock Screen widgets. V1 is serverless, read-only, no auth, no monetization. V2 will add a soul-bound pixel pet NFT; V3 will add quests. V1 must scaffold hooks for V2/V3 without implementing them.

This spec covers only Phase 0: the project skeleton. No business logic, no networking, no real UI. The deliverable is a buildable Xcode project where the main app and widget extension can both read/write a shared file in the `group.io.sui.widget` App Group container, plus a CI pipeline that proves the scaffold continues to build.

## 2. Goals

- Buildable Xcode project with two iOS targets (app + widget extension) and one local Swift package consumed by both
- App Group `group.io.sui.widget` configured on both targets with a working round-trip handshake
- SwiftData stack initialized in the package, schema currently empty, container located in the App Group
- Every file listed in CLAUDE.md "Project structure" exists as a compilable placeholder with correct imports
- GitHub Actions workflow that runs `swift test` on the package and `xcodebuild build` on the iOS project on every push/PR
- Reproducible project generation via XcodeGen so the `.xcodeproj` is rebuildable from `project.yml` and not the source of truth

## 3. Non-goals

- Real UI, real design system, color/typography tokens (deferred until Figma is delivered)
- Any networking code, RPC clients, RSS parsing, image pipeline
- Any populated SwiftData entities (models exist as `@Model` stubs but are not registered in the schema)
- Code signing in CI (CI builds with `CODE_SIGNING_ALLOWED=NO`; local Xcode uses automatic signing with the developer's personal team)
- Real test coverage beyond the App Group handshake (one round-trip test)
- TestFlight build, Apple Developer Program enrollment, App Store Connect setup

## 4. Acceptance criteria

1. `xcodegen generate` produces a `SuiWidget.xcodeproj` that opens in Xcode 16+ without errors
2. The "SuiWidget" scheme builds the app + widget extension for an iOS 17 simulator destination with no warnings
3. Running the app in the simulator displays a `Text` view showing the value written to the App Group container plus a "Write again" button that writes a new ISO-8601 timestamp value
4. Adding the widget to the simulator Home Screen displays the same value the app last wrote; tapping "Write again" then reloading the widget timeline (via `WidgetCenter.shared.reloadAllTimelines()` in the app or via Xcode's widget refresh menu) shows the updated value
5. `swift test --package-path Packages/SuiWidgetKit` runs and passes one `AppGroupStoreTests` round-trip test (using a temp dir, not the real entitlement-backed container)
6. GitHub Actions `.github/workflows/ci.yml` runs both `package-tests` and `ios-build` jobs to green on a clean PR

## 5. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Project generation | XcodeGen | YAML config in repo, `.xcodeproj` is generated and gitignored, easy diff review |
| Swift package location | `Packages/SuiWidgetKit/` (sibling of `SuiWidget/`, not nested as the CLAUDE.md diagram shows) | A local package consumed by two targets is conventionally a sibling; allows `swift test` from a clean macOS runner without Xcode for the fast CI job |
| Bundle IDs | `io.sui.widget` (app), `io.sui.widget.WidgetExtension` (widget) | Matches the locked App Group `group.io.sui.widget` |
| Code signing | Automatic, `DEVELOPMENT_TEAM` blank in `project.yml`; developer picks team on first open | No team ID committed to git; CI bypasses signing |
| Unit test framework | Swift Testing (`@Test`) for both the package test target and the app `SuiWidgetTests` target | Modern default for Swift 5.9+ / Xcode 16; coexists with XCTest in the same bundle. Phase 0 surface is two placeholder tests, so the choice is mostly forward-looking |
| UI test framework | XCTest (XCUITest) | Swift Testing does not replace XCUITest |
| `.xcodeproj` in git | Gitignored | `project.yml` is the source of truth; cloners run `xcodegen generate` per the README |
| iOS deployment target | 17.0 | Locked in CLAUDE.md |
| Swift version | 5.9 | Locked in CLAUDE.md |
| SwiftData schema | Empty (`Schema([])`) for Phase 0 | Phase 1 registers real entities |
| CI runner | `macos-15` | Comes with recent Xcode by default; explicit version override added if Apple ships a new Xcode mid-cycle |
| Design system scaffolding | None — deferred until Figma is delivered | User confirmed; avoids premature abstractions to refactor |

## 6. Repository layout

```
sui-widget/
├── .github/workflows/ci.yml
├── .gitignore                          # ignores SuiWidget.xcodeproj, .build, DerivedData, .DS_Store, xcuserstate
├── CLAUDE.md                           # already exists
├── README.md                           # bootstrap, acceptance, run-the-CI-locally instructions
├── docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md   # this file
├── project.yml                         # XcodeGen — single source of truth for the .xcodeproj
├── SuiWidget.xcodeproj                 # GENERATED — gitignored, produced by `xcodegen generate`
├── SuiWidget/
│   ├── App/
│   │   ├── SuiWidgetApp.swift          # @main App
│   │   ├── AppDelegate.swift           # placeholder
│   │   ├── ContentView.swift           # handshake UI (writes + reads + displays + reload widget button)
│   │   └── Features/
│   │       ├── Onboarding/             # placeholder folder + empty View files
│   │       ├── WalletManagement/
│   │       ├── Portfolio/
│   │       ├── NFTGallery/
│   │       ├── News/
│   │       ├── WidgetConfig/
│   │       └── Settings/
│   ├── Widget/
│   │   ├── SuiWidgetBundle.swift       # @main WidgetBundle wrapping the placeholder widget
│   │   ├── SuiWidgetWidget.swift       # one minimal widget that reads App Group and shows the value
│   │   ├── Provider/
│   │   │   ├── TimelineProvider.swift  # placeholder TimelineProvider returning a single entry
│   │   │   └── WidgetEntry.swift       # TimelineEntry struct with handshakeValue: String
│   │   ├── LockScreen/                 # placeholder Views per CLAUDE.md
│   │   │   ├── CircularWidgetView.swift
│   │   │   ├── RectangularWidgetView.swift
│   │   │   └── InlineWidgetView.swift
│   │   └── HomeScreen/                 # placeholder Views per CLAUDE.md
│   │       ├── SmallWidgetView.swift
│   │       ├── MediumWidgetView.swift
│   │       ├── LargeWidgetView.swift
│   │       └── ExtraLargeWidgetView.swift
│   ├── Resources/
│   │   ├── Assets.xcassets             # empty AppIcon + AccentColor sets
│   │   └── (Info.plist synthesized by XcodeGen — no committed file)
│   ├── Supporting/
│   │   ├── SuiWidget.entitlements      # App Group group.io.sui.widget
│   │   └── SuiWidgetWidget.entitlements
│   └── Tests/
│       ├── SuiWidgetTests/             # Swift Testing — placeholder unit test target
│       │   └── PlaceholderTests.swift
│       └── SuiWidgetUITests/           # XCUITest — placeholder UI test target
│           └── PlaceholderUITests.swift
└── Packages/
    └── SuiWidgetKit/
        ├── Package.swift
        ├── Sources/SuiWidgetKit/
        │   ├── Models/                 # all CLAUDE.md @Model stubs exist; none registered in the schema
        │   │   ├── Wallet.swift
        │   │   ├── TokenHolding.swift
        │   │   ├── PortfolioSnapshot.swift   # houses CachedPortfolio + CachedTokenHolding
        │   │   ├── StakePosition.swift       # houses CachedStakePosition
        │   │   ├── NFTItem.swift             # houses CachedNFTItem
        │   │   ├── NewsItem.swift            # houses CachedNewsItem
        │   │   ├── AppSettings.swift
        │   │   ├── Pet.swift                 # V2 stub
        │   │   └── Quest.swift               # V3 stub
        │   ├── Networking/
        │   │   ├── SuiRPCClient.swift
        │   │   ├── CoinGeckoClient.swift
        │   │   ├── RSSClient.swift
        │   │   └── RPCEndpointRotator.swift
        │   ├── Storage/
        │   │   ├── AppGroupStore.swift       # real impl: file I/O in App Group container, injectable for tests
        │   │   ├── SwiftDataStack.swift      # real impl: Schema([]) + ModelContainer in App Group
        │   │   ├── ImageCache.swift          # placeholder
        │   │   └── ThumbnailGenerator.swift  # placeholder
        │   ├── Services/
        │   │   ├── WalletService.swift
        │   │   ├── PortfolioService.swift
        │   │   ├── NFTService.swift
        │   │   ├── StakingService.swift
        │   │   ├── NewsService.swift
        │   │   └── SuiNSResolver.swift
        │   └── Utilities/
        │       ├── Decimal+Crypto.swift
        │       └── URL+IPFS.swift
        └── Tests/SuiWidgetKitTests/
            └── AppGroupStoreTests.swift      # one real round-trip test using temp dir injection
```

## 7. `project.yml` (XcodeGen) — exact contents

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
    # SWIFT_STRICT_CONCURRENCY is left at the default ("minimal") for Phase 0
    # to avoid blocking on concurrency diagnostics in placeholder code.
    # Raised to "complete" in Phase 1+ when real async code lands.

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
    sources: [SuiWidget/Tests/SuiWidgetTests]
    dependencies:
      - target: SuiWidget

  SuiWidgetUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [SuiWidget/Tests/SuiWidgetUITests]
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

XcodeGen synthesizes the app's `Info.plist` from the `INFOPLIST_KEY_*` settings (because `GENERATE_INFOPLIST_FILE: YES`). The widget extension takes the opposite approach: `GENERATE_INFOPLIST_FILE: NO` plus an explicit `info:` block, because the `NSExtension` dictionary contains nested keys that the `INFOPLIST_KEY_*` mechanism does not support. The widget's `Info.plist` file is written by XcodeGen during `xcodegen generate` and is gitignored (consistent with the `.xcodeproj` itself being gitignored). `project.yml` is the only source of truth; every cloner runs `xcodegen generate` before opening the project.

## 8. Swift package `Packages/SuiWidgetKit/Package.swift`

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

macOS 14 in `platforms` allows `swift test` to run from the CLI on a Mac runner without Xcode being involved. Anything iOS-only added in later phases will be guarded with `#if canImport(UIKit)` or `#if os(iOS)`.

## 9. Entitlements files

`SuiWidget/Supporting/SuiWidget.entitlements`:

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

`SuiWidget/Supporting/SuiWidgetWidget.entitlements` has identical contents. Both files are committed.

## 10. App Group handshake — concrete design

### `AppGroupStore`

`Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/AppGroupStore.swift`:

```swift
import Foundation

public struct AppGroupStore {
    public static let groupIdentifier = "group.io.sui.widget"
    public static let handshakeFilename = "handshake.json"

    private let containerURL: URL

    /// Production initializer — uses the App Group container.
    /// Fails if the entitlement is missing (e.g. running outside an entitled target).
    public init() throws {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.groupIdentifier
        ) else {
            throw AppGroupStoreError.containerUnavailable
        }
        self.containerURL = url
    }

    /// Test initializer — uses an injected directory.
    public init(containerURL: URL) {
        self.containerURL = containerURL
    }

    public var handshakeURL: URL {
        containerURL.appendingPathComponent(Self.handshakeFilename)
    }

    public func writeHandshake(_ value: String) throws {
        let payload = HandshakePayload(value: value, writtenAt: Date())
        let data = try JSONEncoder().encode(payload)
        try data.write(to: handshakeURL, options: .atomic)
    }

    public func readHandshake() throws -> HandshakePayload? {
        guard FileManager.default.fileExists(atPath: handshakeURL.path) else { return nil }
        let data = try Data(contentsOf: handshakeURL)
        return try JSONDecoder().decode(HandshakePayload.self, from: data)
    }
}

public struct HandshakePayload: Codable, Equatable {
    public let value: String
    public let writtenAt: Date
}

public enum AppGroupStoreError: Error {
    case containerUnavailable
}
```

### Main app handshake UI

`SuiWidget/App/ContentView.swift`:

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
            labelRow("Wrote:", lastWritten)
            labelRow("Read back:", lastRead)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }
            Button("Write again") { writeAndReload() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { writeAndReload() }
    }

    @ViewBuilder
    private func labelRow(_ label: String, _ payload: HandshakePayload?) -> some View {
        HStack {
            Text(label).bold()
            Text(payload?.value ?? "—").monospaced()
            Spacer()
        }
    }

    private func writeAndReload() {
        do {
            let store = try AppGroupStore()
            let value = "hello-\(ISO8601DateFormatter().string(from: Date()))"
            try store.writeHandshake(value)
            lastWritten = try store.readHandshake()
            lastRead = lastWritten
            WidgetCenter.shared.reloadAllTimelines()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
```

### Widget

`SuiWidget/Widget/SuiWidgetBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct SuiWidgetBundle: WidgetBundle {
    var body: some Widget { SuiWidgetWidget() }
}
```

`SuiWidget/Widget/SuiWidgetWidget.swift`:

```swift
import WidgetKit
import SwiftUI
import SuiWidgetKit

struct SuiWidgetWidget: Widget {
    let kind = "SuiWidgetWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HandshakeTimelineProvider()) { entry in
            VStack {
                Text("Sui Widget").font(.caption).bold()
                Text(entry.handshakeValue).font(.caption2).monospaced()
            }
            .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Sui Handshake")
        .description("Phase 0 placeholder — shows the value written by the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

`SuiWidget/Widget/Provider/TimelineProvider.swift`:

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
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
    private func currentEntry() -> HandshakeEntry {
        let value = (try? AppGroupStore().readHandshake()?.value) ?? "(no value)"
        return HandshakeEntry(date: Date(), handshakeValue: value)
    }
}
```

`SuiWidget/Widget/Provider/WidgetEntry.swift`:

```swift
import WidgetKit

struct HandshakeEntry: TimelineEntry {
    let date: Date
    let handshakeValue: String
}
```

The other widget view files listed in CLAUDE.md (`CircularWidgetView`, `SmallWidgetView`, etc.) are created as empty `View` placeholders not wired into the configuration; they exist so Phase 3 has the file paths already in place.

### Automated test

`Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/AppGroupStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import SuiWidgetKit

@Suite struct AppGroupStoreTests {
    @Test func roundTripsHandshakeValue() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        try store.writeHandshake("test-value")
        let read = try store.readHandshake()
        #expect(read?.value == "test-value")
    }
}
```

Because the CLI test runs without the App Group entitlement, this test uses the injected-directory initializer. The entitlement is exercised by the in-simulator visual handshake (acceptance criterion 3 + 4).

## 11. SwiftData stack

`Packages/SuiWidgetKit/Sources/SuiWidgetKit/Storage/SwiftDataStack.swift`:

```swift
import Foundation
import SwiftData

public enum SwiftDataStack {
    public static let schema = Schema([])      // Phase 1 will register models here

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "SuiWidget",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .identifier("group.io.sui.widget")
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
```

Not invoked by Phase 0 acceptance — the handshake is plain file I/O, not SwiftData. The stack exists so Phase 1 can immediately register `Wallet`, `CachedPortfolio`, etc. without changing call sites.

## 12. Placeholder file convention

Every file in CLAUDE.md "Project structure" exists at the path defined in section 6. Conventions:

- **SwiftUI views:** `struct <Name>: View { var body: some View { Text("TODO: <Name>") } }`
- **Networking clients / services:** empty `public struct` or `public actor` with a `public init() {}` and a single `// TODO: implement in Phase 1` comment
- **`@Model` types (Wallet, TokenHolding, etc.):** fully declared per CLAUDE.md "Data models" section so the type system is real; **none** are registered in `SwiftDataStack.schema` until Phase 1
- **Utilities:** empty extension declarations (`extension Decimal {}`, `extension URL {}`)
- **V2/V3 stubs (`Pet`, `Quest`, `ActivityEvent`):** `@Model` declared, never instantiated, marked with a `/// V2 stub — not active in V1` doc comment

Every placeholder compiles. No `fatalError`, no unimplemented stubs that would crash the app if accidentally invoked.

## 13. CI workflow

`.github/workflows/ci.yml`:

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

The runner's default Xcode is used (macos-15 ships with Xcode 16.x, sufficient for iOS 17). If Apple ships an Xcode that breaks the build, pin to a specific path with `sudo xcode-select -s /Applications/Xcode_<version>.app` and revisit `macos-15` vs a newer runner image.

## 14. `.gitignore`

Standard Swift/Xcode gitignore plus generated and user-state files:

```
# Xcode
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

## 15. README

`README.md` covers:

- One-paragraph project intro pointing at CLAUDE.md
- Prerequisites: macOS, Xcode 16+, Homebrew, `brew install xcodegen`
- Bootstrap: `xcodegen generate` → open `SuiWidget.xcodeproj` → pick Development Team on both targets → Run
- Phase 0 acceptance recipe: run app, observe handshake value, add widget to Home Screen, tap Write again, observe widget refresh
- How to run the package tests locally: `swift test --package-path Packages/SuiWidgetKit`

## 16. Bootstrap execution sequence

After this spec is approved and the writing-plans skill produces an implementation plan, execution proceeds in this order:

1. `git init` and create an initial commit containing `CLAUDE.md` + this spec (and `docs/` scaffold)
2. `brew install xcodegen` (skip if already present)
3. Write `.gitignore`, `README.md`, `project.yml`
4. Write `Packages/SuiWidgetKit/Package.swift` and every package source file (placeholders + real `AppGroupStore` + real `SwiftDataStack`)
5. Write `Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/AppGroupStoreTests.swift`
6. Write entitlements files (`SuiWidget.entitlements`, `SuiWidgetWidget.entitlements`)
7. Write all app target source files (placeholders + real `ContentView` handshake + `SuiWidgetApp`)
8. Write all widget target source files (placeholders + real `SuiWidgetBundle`, `SuiWidgetWidget`, `HandshakeTimelineProvider`, `HandshakeEntry`)
9. Write empty `Assets.xcassets` with default AppIcon and AccentColor sets
10. Write `.github/workflows/ci.yml`
11. Run `xcodegen generate` and verify `SuiWidget.xcodeproj` is produced
12. Run `swift test --package-path Packages/SuiWidgetKit` and verify the round-trip test passes
13. Run `xcodebuild build` on the generated project against an iOS Simulator destination to confirm it compiles
14. Hand the project to the user for in-simulator acceptance (steps 3–4 of section 4)
15. After acceptance passes, commit the scaffold and push to GitHub; observe CI

Steps 2 and 11–13 cannot run until Xcode is fully installed locally (xcode-select switched, license accepted, iOS Simulator runtime downloaded).

## 17. Open items deferred to Phase 1+

- Real models registered in `SwiftDataStack.schema`
- Networking clients, RPC endpoint rotator
- Image pipeline (IPFS gateway rotation, ImageIO resize, App Group thumbnail storage)
- BG tasks (`io.sui.widget.refresh`, `io.sui.widget.cleanup`, `io.sui.widget.coinlist`) and `Info.plist` `BGTaskSchedulerPermittedIdentifiers` entries
- Design system / Figma import (waiting on user-supplied designs)
- Localization strings catalog
- Snapshot test infrastructure for widget rendering
