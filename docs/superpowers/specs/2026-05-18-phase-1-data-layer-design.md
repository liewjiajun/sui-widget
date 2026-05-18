# Phase 1 — Data Layer Design

**Status:** Approved 2026-05-18
**Scope:** CLAUDE.md "Phase 1: Data layer (Weeks 2-3)" plus the Phase 0 deferred items in `docs/superpowers/phase-1-prep.md`
**Implements:** SuiRPCClient + endpoint rotation + exponential backoff, CoinGeckoClient with TTL caching + batched prices, RSSClient (FeedKit), SuiNSResolver, image pipeline (download + IPFS gateway rotation + ImageIO resize + App Group storage), all SwiftData models registered in `SwiftDataStack.schema`, minimal Services layer that orchestrates the clients for the integration target

## 1. Context

Phase 0 shipped the project skeleton — app + widget targets, an App Group-backed `AppGroupStore` for a tiny round-trip handshake, and `SwiftDataStack` with an empty schema. Phase 1 fills the data layer that makes the brief's "fetch and cache balances, NFTs, stakes, prices, news ... all readable via shared framework" acceptance criterion real.

Everything Phase 1 builds is in the `SuiWidgetKit` Swift package — no app/widget changes except the cleanup migration of `AppGroupStore` to `async throws`. The package remains macOS-buildable for the fast `swift test` CI job; the image pipeline turned out to be cross-platform via Core Graphics + ImageIO, so no `#if canImport(UIKit)` guards are needed.

## 2. Goals

- Every Sui mainnet RPC method the brief lists works against fixtures and against the live test wallet
- CoinGecko coin list + market data work; portfolio 24h change math is implemented per the brief's formula
- RSS feeds (blog + GitHub releases) merge, dedupe, sort
- SuiNS resolution for `0x...`, `name.sui`, `@name`
- Image pipeline downloads, rotates IPFS gateways on failure, resizes via ImageIO, stores in App Group, returns file URL
- All `@Model` entities registered in the schema, with Phase 0 deferred items resolved
- `PortfolioService.refresh(walletId:)` is the single integration entry point: it orchestrates clients, populates SwiftData, returns a complete `CachedPortfolio`
- Unit tests for every networking type using committed JSON fixtures — zero live network in the `swift test` path
- One disabled-by-default live integration test that proves the whole layer end-to-end against a chosen public mainnet wallet

## 3. Non-goals

- BGTaskScheduler registration in `AppDelegate` (Phase 2)
- Widget timeline reload triggered by cache updates (Phase 2 — services don't know about widgets)
- Real UI consuming the services (Phase 2)
- Feature flags for Quest list screen (Phase 3 — V3 hook)
- iCloud sync of wallet list (V2)
- Localized error strings (Phase 4)
- Snapshot tests for widget rendering (Phase 3)
- Address ENS / non-Sui resolution
- Custom RPC endpoint configuration (locked at three mainnet endpoints per CLAUDE.md)

## 4. Acceptance criteria

1. **`swift test --package-path Packages/SuiWidgetKit` passes**, all tests use fixtures, **zero network calls** during the test run
2. SuiRPCClient covers seven methods (`getAllBalances`, `getCoinMetadata`, `getOwnedObjects`, `getStakes`, `getLatestSuiSystemState`, `resolveNameServiceAddress`, `resolveNameServiceNames`) with typed responses
3. CoinGeckoClient produces a `[coinType: coingeckoId]` map from a coin-list fixture, fetches batched prices from a markets fixture, persists to `CachedCoinListEntry`
4. RSSClient.fetchMerged returns ≤30 deduped items sorted by `publishedAt` desc when given fixture feeds
5. SuiNSResolver resolves `0x...`, `name.sui`, `@name` to addresses against fixtures; reverse-resolves an address to a name; cache hits skip network
6. Image pipeline: given a small PNG fixture, `ThumbnailGenerator.generateBoth(objectId:url:)` writes 200×200 and 600×600 JPEGs to a temp App Group directory and returns their URLs
7. `SwiftDataStack.schema` registers all entities; `makeContainer(inMemory: true)` succeeds; all Phase 0 deferred items resolved (cascade rules, unique IDs, `AppSettings` singleton, `Quest.summary`, `CachedNFTItem.objectId` uniqueness, status enums, `ActivityEvent` added)
8. `PortfolioService.refresh(walletId:)` integration test (disabled by default, enabled via filter) successfully fetches live data for the chosen public Sui mainnet wallet and prints non-empty token balances, prices, and stake positions
9. `xcodebuild build -scheme SuiWidget` continues to succeed (Phase 0 acceptance preserved)
10. GitHub Actions CI green on both jobs (`package-tests` runs the swift-test fixture suite; `ios-build` runs xcodebuild)

## 5. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Concurrency model | Swift `actor` for shared mutable state (`RPCEndpointRotator`, `ImageCache`); `struct` for stateless types (`HTTPClient`, RPC clients) | Actors guarantee data-race safety; structs avoid actor-hop overhead for stateless paths |
| Error handling | Per-component error enums conforming to `LocalizedError` | Diagnosable failures; localization in Phase 4 |
| HTTP layer | Shared `HTTPClient` struct with retry + exponential backoff (`base 500ms × 2^attempt`, jitter ±20%), max 3 attempts, retries on 429/5xx/timeout | One place to tune retry policy; injectable for tests |
| Endpoint rotation | `RPCEndpointRotator` actor; per-endpoint failure count resets every 5 min (lazy check on call) | Matches CLAUDE.md; simpler than a background timer |
| Sui address type | `public struct SuiAddress` value type (validated 0x + 64 hex, lowercased) | Prevents stringly-typed bugs across services |
| Coin type | Keep as `String` | A typed wrapper is over-engineering at this stage |
| u64 → Decimal | Custom Codable container in `SuiRPCTypes.swift`; helper `Decimal(suiU64String:)` in `Decimal+Crypto.swift` | Sui RPC encodes u64 as JSON strings; Decimal preserves precision |
| Cache TTL location | Per-entity `cachedAt: Date` for `CachedValidatorMetadata` and `CachedSuiNSResolution`; whole-collection timestamp on `AppSettings` for coin list + news (one timestamp covers many rows) | Avoid redundant per-row timestamps when the entire collection refreshes together |
| Image library | Custom `URLSession` + `ImageIO` + `CGImageDestination` | Matches the "no SDK dependency" pattern (same as Sui RPC); platform-provided; ~250 LOC |
| Image cache key | `SHA256(objectId + ":" + sizeString)` via CryptoKit | Stable + safe for filename |
| Image platform support | Fully cross-platform via Core Graphics + ImageIO (no `UIImage` exposed). Phase 0 prep #8 anticipated `#if canImport(UIKit)` guards, but ImageIO works on macOS 14 too. Image pipeline tests run on both platforms in `swift test`. | Simpler than dual-platform stubs; the resize logic is testable from macOS CI |
| IPFS gateway order | `ipfs.io` → `cloudflare-ipfs.com` → `dweb.link`, fall through on 404/timeout | Per CLAUDE.md image pipeline |
| FeedKit version | `^11.0.0` (latest 11.x as of 2026-05) in `Package.swift` | Recent stable; CLAUDE.md locks FeedKit as the RSS parser |
| Test framework | Swift Testing (`@Test`, `#expect`) for unit tests; XCTest for the existing UI test target only | Continues Phase 0 pattern |
| Fixture location | `Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/Fixtures/` — JSON + binary files committed | Reproducible; CI runs offline |
| Fixture generation | Live-record once during plan execution via `curl` against the chosen mainnet wallet; commit raw responses | Realistic data; future schema-drift bugs surface as fixture-replay failures |
| Live integration test | One Swift Testing `@Suite("Live integration").disabled()` — enabled manually via `swift test --filter` | Single source of truth for "does the whole layer actually work?" |
| Test wallet | A public Sui Foundation / Mysten Labs mainnet address with multi-token, NFT, and stake holdings — specific address picked during plan execution from public on-chain explorers (e.g., Suiscan / Suivision) | Diverse fixture data; no need to expose a private wallet |
| `CachedNFTItem.objectId` | `@Attribute(.unique)` — one row per on-chain NFT across all wallets | NFTs are unique on-chain; widget shows one or zero copies |
| `Quest.summary` field name | Keep as `summary`; CLAUDE.md is updated to match | Better Swift (avoids shadowing `CustomStringConvertible.description`) |
| Status enums | `StakeStatus`, `QuestStatus`, `NewsSource` — `String`-backed `RawRepresentable: Codable` | Prevents stringly-typed drift before Phase 3 UI lands |
| `ActivityEvent` model | Added with fields `id, walletAddress, eventType: ActivityEventKind, timestamp, metadata: [String:String]` | V3 hook per Phase 0 prep #16; never written by Phase 1 |
| Schema location | All models listed in `SwiftDataStack.schema` array, alphabetical by entity name | Stable registration order avoids migration surprises |
| Services API style | Each service is a `struct` taking its dependencies via initializer (clients + `ModelContext`); methods are `async throws` | Testable; no hidden singletons; aligns with structured concurrency |
| `PortfolioService.refresh` semantics | Cache-replacement: delete existing `CachedPortfolio` for the wallet (cascade clears children), insert fresh | Simpler than diff-based upsert; safe because cascade is enforced |

## 6. Repository layout — files added / modified

```
Packages/SuiWidgetKit/
├── Package.swift                                   # MODIFIED — adds FeedKit dependency
└── Sources/SuiWidgetKit/
    ├── Models/
    │   ├── ActivityEvent.swift                     # NEW — V3 hook
    │   ├── AppSettings.swift                       # MODIFIED — singleton key, new timestamp fields
    │   ├── CachedCoinListEntry.swift               # NEW
    │   ├── CachedSuiNSResolution.swift             # NEW
    │   ├── CachedValidatorMetadata.swift           # NEW
    │   ├── NFTItem.swift                           # MODIFIED — CachedNFTItem.objectId becomes unique
    │   ├── NewsItem.swift                          # MODIFIED — CachedNewsItem.source becomes NewsSource enum
    │   ├── NewsSource.swift                        # NEW enum
    │   ├── Pet.swift                               # unchanged (V2 stub)
    │   ├── PortfolioSnapshot.swift                 # MODIFIED — cascade rules, unique id on CachedTokenHolding
    │   ├── Quest.swift                             # MODIFIED — confirmed summary field, status becomes QuestStatus enum
    │   ├── QuestStatus.swift                       # NEW enum
    │   ├── StakePosition.swift                     # MODIFIED — unique id on CachedStakePosition, status becomes StakeStatus enum
    │   ├── StakeStatus.swift                       # NEW enum
    │   ├── SuiAddress.swift                        # NEW value type
    │   ├── TokenHolding.swift                      # unchanged (plain struct value type, not @Model)
    │   └── Wallet.swift                            # unchanged
    ├── Networking/
    │   ├── CoinGeckoClient.swift                   # REAL IMPL replacing placeholder
    │   ├── CoinGeckoError.swift                    # NEW
    │   ├── CoinGeckoTypes.swift                    # NEW — Codable response shapes
    │   ├── HTTPClient.swift                        # NEW
    │   ├── HTTPClientError.swift                   # NEW
    │   ├── IPFSGatewayResolver.swift               # NEW
    │   ├── ImageDownloader.swift                   # NEW
    │   ├── ImagePipelineError.swift                # NEW
    │   ├── ImageResizer.swift                      # NEW (cross-platform via Core Graphics + ImageIO)
    │   ├── RPCEndpointRotator.swift                # REAL IMPL replacing placeholder (actor)
    │   ├── RSSClient.swift                         # REAL IMPL replacing placeholder
    │   ├── RSSError.swift                          # NEW
    │   ├── SuiRPCClient.swift                      # REAL IMPL replacing placeholder
    │   ├── SuiRPCError.swift                       # NEW
    │   └── SuiRPCTypes.swift                       # NEW — Codable response shapes
    ├── Services/
    │   ├── NFTService.swift                        # REAL IMPL
    │   ├── NewsService.swift                       # REAL IMPL
    │   ├── PortfolioService.swift                  # REAL IMPL
    │   ├── StakingService.swift                    # REAL IMPL
    │   ├── SuiNSError.swift                        # NEW
    │   ├── SuiNSResolver.swift                     # REAL IMPL
    │   └── WalletService.swift                     # REAL IMPL
    ├── Storage/
    │   ├── AppGroupStore.swift                     # MODIFIED — async write/read
    │   ├── ImageCache.swift                        # REAL IMPL (actor)
    │   ├── SwiftDataStack.swift                    # MODIFIED — populated schema
    │   └── ThumbnailGenerator.swift                # REAL IMPL (cross-platform)
    └── Utilities/
        ├── Decimal+Crypto.swift                    # MODIFIED — real helpers
        └── URL+IPFS.swift                          # MODIFIED — real helpers

Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/
├── AppGroupStoreTests.swift                        # MODIFIED — async
├── CoinGeckoClientTests.swift                      # NEW
├── Fixtures/                                       # NEW directory, ~20 files
│   ├── sui-getAllBalances-success.json
│   ├── sui-getCoinMetadata-sui.json
│   ├── sui-getCoinMetadata-usdc.json
│   ├── sui-getOwnedObjects-page1.json
│   ├── sui-getStakes-success.json
│   ├── sui-getLatestSuiSystemState.json
│   ├── sui-resolveNameServiceAddress-success.json
│   ├── sui-resolveNameServiceAddress-missing.json
│   ├── sui-resolveNameServiceNames-success.json
│   ├── sui-error-429.json
│   ├── coingecko-coins-list-sui-platform.json
│   ├── coingecko-coins-markets-multi.json
│   ├── rss-sui-blog.xml
│   ├── rss-mysten-releases.atom
│   ├── nft-thumbnail-input.png
│   └── README.md                                   # how fixtures were recorded
├── Helpers/
│   ├── FixtureLoader.swift                         # NEW
│   └── MockHTTPClient.swift                        # NEW
├── HTTPClientTests.swift                           # NEW
├── ImagePipelineTests.swift                        # NEW
├── LiveIntegrationTests.swift                      # NEW — disabled by default
├── NFTServiceTests.swift                           # NEW
├── NewsServiceTests.swift                          # NEW
├── PortfolioServiceTests.swift                     # NEW
├── RPCEndpointRotatorTests.swift                   # NEW
├── RSSClientTests.swift                            # NEW
├── StakingServiceTests.swift                       # NEW
├── SuiAddressTests.swift                           # NEW
├── SuiNSResolverTests.swift                        # NEW
├── SuiRPCClientTests.swift                         # NEW
└── WalletServiceTests.swift                        # NEW

SuiWidget/
├── App/
│   └── ContentView.swift                           # MODIFIED — calls async AppGroupStore via Task
└── Widget/
    └── Provider/TimelineProvider.swift             # MODIFIED — calls async AppGroupStore
```

## 7. SwiftData models — full schema after Phase 1

### Phase 0 prep items resolved (one refactor commit)

- `CachedPortfolio` relationships gain `deleteRule: .cascade`
- `CachedTokenHolding` and `CachedStakePosition` gain `@Attribute(.unique) public var id: UUID`
- `AppSettings` gains `@Attribute(.unique) public var singletonKey: String = "default"` plus new timestamp fields (`lastCoinListFetchedAt: Date?`, `lastNewsFetchedAt: Date?`)
- `CachedNFTItem.objectId` gains `@Attribute(.unique)`
- `Quest.summary` confirmed (CLAUDE.md updated to match)
- `CachedStakePosition.status` becomes `StakeStatus` enum
- `Quest.status` becomes `QuestStatus` enum
- `CachedNewsItem.source` becomes `NewsSource` enum

### New models

```swift
// CachedValidatorMetadata
@Model public final class CachedValidatorMetadata {
    @Attribute(.unique) public var validatorAddress: String
    public var name: String
    public var imageURL: String?
    public var description_: String?    // SwiftData reserves `description`; trailing underscore
    public var commissionRate: Double
    public var stakingPool: String
    public var cachedAt: Date
    public init(...) { ... }            // memberwise
}

// CachedCoinListEntry — one row per Sui-tracked CoinGecko coin
@Model public final class CachedCoinListEntry {
    @Attribute(.unique) public var coinType: String   // e.g. 0x2::sui::SUI
    public var coingeckoId: String                    // e.g. "sui"
    public var symbol: String
    public var name: String
    public init(...) { ... }
}

// CachedSuiNSResolution
@Model public final class CachedSuiNSResolution {
    @Attribute(.unique) public var name: String      // e.g. "alice.sui" (lowercased, no @ prefix)
    public var address: String                        // resolved 0x...
    public var cachedAt: Date
    public init(...) { ... }
}

// ActivityEvent — V3 hook
@Model public final class ActivityEvent {
    @Attribute(.unique) public var id: UUID
    public var walletAddress: String
    public var eventType: ActivityEventKind            // String-backed enum
    public var timestamp: Date
    public var metadata: [String: String]
    public init(...) { ... }
}

public enum ActivityEventKind: String, Codable {
    case walletAdded
    case walletRemoved
    case portfolioRefreshed
    case nftSynced
    case stakeSynced
    case newsRefreshed
}
```

### New enums

```swift
public enum StakeStatus: String, Codable, CaseIterable {
    case active
    case pending
    case withdrawing
}

public enum QuestStatus: String, Codable, CaseIterable {
    case available
    case inProgress = "in_progress"
    case completed
}

public enum NewsSource: String, Codable, CaseIterable {
    case blog
    case githubRelease = "github_release"
}
```

### `SwiftDataStack.schema` final form

```swift
public static let schema = Schema([
    ActivityEvent.self,
    AppSettings.self,
    CachedCoinListEntry.self,
    CachedNFTItem.self,
    CachedNewsItem.self,
    CachedPortfolio.self,
    CachedStakePosition.self,
    CachedSuiNSResolution.self,
    CachedTokenHolding.self,
    CachedValidatorMetadata.self,
    Pet.self,
    Quest.self,
    Wallet.self,
])
```

### `SuiAddress` value type

```swift
public struct SuiAddress: Hashable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String          // always lowercase, 0x-prefixed, 66 chars total
    public init?(rawValue: String) {
        let lower = rawValue.lowercased()
        guard lower.hasPrefix("0x"), lower.count == 66,
              lower.dropFirst(2).allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
        self.rawValue = lower
    }
    public var description: String { rawValue }
}
```

## 8. Networking foundation

### `HTTPClient` (struct)

```swift
public struct HTTPClient {
    public struct RetryPolicy {
        public var maxAttempts: Int = 3
        public var baseDelay: TimeInterval = 0.5    // 500 ms
        public var jitterFactor: Double = 0.2       // ±20%
    }
    public let session: URLSession
    public let retryPolicy: RetryPolicy
    public init(session: URLSession = .shared, retryPolicy: RetryPolicy = .init())

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```

Retry rules:
- Retry on HTTP 429, 5xx
- Retry on `URLError.timedOut`, `URLError.networkConnectionLost`, `URLError.cannotConnectToHost`
- Do NOT retry on 4xx (other than 429), `URLError.cancelled`, malformed URL
- Delay before attempt N: `baseDelay × 2^(N-1) × (1 + uniform_random(-jitterFactor, +jitterFactor))`
- After `maxAttempts` failures, throw `HTTPClientError.exhausted(lastStatus:, lastError:)`

### `HTTPClientError`

```swift
public enum HTTPClientError: Error, LocalizedError {
    case invalidResponse
    case unexpectedStatus(Int)
    case exhausted(lastStatus: Int?, lastError: Error?)
    case clientError(Int)                            // non-retryable 4xx
    public var errorDescription: String? { ... }
}
```

### `RPCEndpointRotator` (actor)

```swift
public actor RPCEndpointRotator {
    public static let mainnetEndpoints: [URL] = [
        URL(string: "https://fullnode.mainnet.sui.io:443")!,
        URL(string: "https://sui-mainnet.public.blastapi.io")!,
        URL(string: "https://sui-mainnet-rpc.allthatnode.com")!,
    ]
    public init(endpoints: [URL] = mainnetEndpoints, clock: @Sendable @escaping () -> Date = { Date() })

    public func currentEndpoint() -> URL                            // returns first healthy endpoint
    public func recordFailure(at endpoint: URL)                     // increments failure count; resets stale counts on entry
    public func recordSuccess(at endpoint: URL)                     // clears failure count for that endpoint
}
```

Health policy:
- An endpoint is healthy when its failure count < 3 within the last 5 minutes
- All failure counts older than 5 min reset on any subsequent call (lazy reset)
- `currentEndpoint()` returns the first healthy endpoint in declaration order; if all unhealthy, returns the one with the lowest count
- Injectable `clock` for deterministic testing

## 9. SuiRPCClient

```swift
public struct SuiRPCClient {
    public let http: HTTPClient
    public let rotator: RPCEndpointRotator
    public init(http: HTTPClient = .init(), rotator: RPCEndpointRotator = .init())

    public func getAllBalances(owner: SuiAddress) async throws -> [SuiBalance]
    public func getCoinMetadata(coinType: String) async throws -> SuiCoinMetadata
    public func getOwnedObjects(owner: SuiAddress, limit: Int = 50, cursor: String? = nil)
        async throws -> SuiOwnedObjectsPage
    public func getStakes(owner: SuiAddress) async throws -> [SuiDelegatedStake]
    public func getLatestSuiSystemState() async throws -> SuiSystemState
    public func resolveNameServiceAddress(name: String) async throws -> SuiAddress?
    public func resolveNameServiceNames(address: SuiAddress) async throws -> [String]
}
```

Internal flow per call:
1. Build JSON-RPC body `{ "jsonrpc": "2.0", "id": 1, "method": "<name>", "params": [...] }`
2. Loop up to `rotator.endpoints.count` rotations:
   - `let endpoint = await rotator.currentEndpoint()`
   - Construct `URLRequest`, POST via `http.send`
   - On `HTTPClientError.exhausted` or status not in 2xx → `await rotator.recordFailure(at: endpoint)`, continue
   - On 2xx → decode `JSONRPCResponse<T>`; if it has an `error` field → throw `SuiRPCError.rpcError(code:, message:)`
3. If all rotations exhausted → throw `SuiRPCError.allEndpointsFailed`

### Response types (excerpt)

```swift
public struct SuiBalance: Codable, Equatable {
    public let coinType: String
    public let coinObjectCount: Int
    public let totalBalance: Decimal                 // custom Codable container parses string → Decimal
}

public struct SuiCoinMetadata: Codable, Equatable {
    public let decimals: Int
    public let name: String
    public let symbol: String
    public let description: String
    public let iconUrl: String?
}

public struct SuiOwnedObjectsPage: Codable, Equatable {
    public let data: [SuiOwnedObject]
    public let nextCursor: String?
    public let hasNextPage: Bool
}

public struct SuiOwnedObject: Codable, Equatable {
    public let objectId: String
    public let type: String?
    public let display: [String: String]?            // resolved from Display{} object
}

public struct SuiDelegatedStake: Codable, Equatable {
    public let validatorAddress: String
    public let stakingPool: String
    public let stakes: [SuiStakeEntry]
}

public struct SuiStakeEntry: Codable, Equatable {
    public let stakedSuiId: String
    public let stakeRequestEpoch: String
    public let principal: Decimal                    // u64 → Decimal
    public let status: StakeStatus
    public let estimatedReward: Decimal?
}

public struct SuiSystemState: Codable, Equatable {
    public let epoch: String
    public let activeValidators: [SuiValidatorInfo]
}

public struct SuiValidatorInfo: Codable, Equatable {
    public let suiAddress: String
    public let name: String
    public let imageUrl: String?
    public let description: String?
    public let commissionRate: String
    public let stakingPoolId: String
}
```

### `SuiRPCError`

```swift
public enum SuiRPCError: Error, LocalizedError {
    case allEndpointsFailed
    case rpcError(code: Int, message: String)
    case decodingFailed(underlying: Error)
    case invalidAddress(String)
}
```

## 10. CoinGeckoClient

```swift
public struct CoinGeckoClient {
    public static let baseURL = URL(string: "https://api.coingecko.com/api/v3")!
    public let http: HTTPClient
    public let modelContext: ModelContext

    public init(http: HTTPClient = .init(), modelContext: ModelContext)

    /// Refreshes the Sui-coin → CoinGecko-id map. Persists to CachedCoinListEntry rows;
    /// writes lastCoinListFetchedAt onto AppSettings. Returns the live mapping.
    /// Internal TTL check: if `AppSettings.lastCoinListFetchedAt` is within 24h, returns the
    /// persisted rows without a network call.
    public func refreshCoinList(force: Bool = false) async throws -> [CoinTypeMapping]

    /// Batched call for current price + 24h change.
    /// IDs are CoinGecko IDs; not coin types. Caller is responsible for the coinType→id lookup.
    public func fetchPrices(coingeckoIds: [String]) async throws -> [CoinGeckoMarket]
}

public struct CoinTypeMapping: Codable, Equatable {
    public let coinType: String          // 0x...::module::TYPE
    public let coingeckoId: String       // e.g. "sui"
    public let symbol: String
    public let name: String
}

public struct CoinGeckoMarket: Codable, Equatable {
    public let id: String                // coingeckoId
    public let symbol: String
    public let currentPrice: Decimal
    public let priceChangePercentage24h: Double
    public let image: String?
}
```

Coin-list endpoint: `GET /coins/list?include_platform=true`. Response is `[CoinGeckoListEntry]` where each entry has `id, symbol, name, platforms: [String: String?]`. Filter to entries where `platforms["sui"]` is non-empty; `coinType = platforms["sui"]!`.

Markets endpoint: `GET /coins/markets?vs_currency=usd&ids=<csv>`. Batched single call for up to 250 ids per CoinGecko free-tier limit. If >250, paginate.

### Errors

```swift
public enum CoinGeckoError: Error, LocalizedError {
    case http(HTTPClientError)
    case decodingFailed(underlying: Error)
    case rateLimitExceeded
    case unexpectedShape
}
```

## 11. RSSClient

Package dependency added in `Package.swift`:

```swift
.package(url: "https://github.com/nmdias/FeedKit.git", from: "11.0.0"),
```

```swift
public struct RSSClient {
    public static let suiBlogURL = URL(string: "https://blog.sui.io/rss.xml")!
    public static let mystenReleasesURL = URL(string: "https://github.com/MystenLabs/sui/releases.atom")!
    public let http: HTTPClient
    public init(http: HTTPClient = .init())

    public func fetchBlog() async throws -> [RawNewsItem]
    public func fetchGitHubReleases() async throws -> [RawNewsItem]

    /// Fetches both feeds in parallel via async let, merges, sorts by publishedAt desc,
    /// dedupes by SHA256(url), returns top 30.
    public func fetchMerged(limit: Int = 30) async throws -> [RawNewsItem]
}

public struct RawNewsItem: Equatable, Hashable {
    public let urlHash: String           // SHA256 hex of url string — used as id
    public let title: String
    public let url: String
    public let publishedAt: Date
    public let source: NewsSource
    public let summary: String?
}
```

`fetchBlog()` parses RSS via `FeedKit.FeedParser`. `fetchGitHubReleases()` parses Atom via the same. Date parsing uses the feed's published/updated fields with fallback to current time on malformed.

### Errors

```swift
public enum RSSError: Error, LocalizedError {
    case http(HTTPClientError)
    case parseFailed(underlying: Error)
    case noEntries
}
```

## 12. SuiNSResolver

```swift
public struct SuiNSResolver {
    public let rpc: SuiRPCClient
    public let modelContext: ModelContext

    /// Accepts: `0x...` (returned as-is after validation),
    /// `name.sui` (lookup), `@name` (treated as `name.sui`).
    public func resolve(_ input: String) async throws -> SuiAddress

    public func reverseResolve(address: SuiAddress) async throws -> String?
}
```

Internal flow for `resolve`:
1. If input starts with `0x` → construct `SuiAddress`, throw `SuiNSError.invalidAddress` on failure
2. Normalize: drop leading `@`, lowercase, ensure ends with `.sui`
3. Look up `CachedSuiNSResolution` by `name`; if `cachedAt > Date() - 1h`, return persisted `SuiAddress`
4. Call `rpc.resolveNameServiceAddress(name:)`; if `nil` → throw `SuiNSError.nameNotFound(name)`
5. Upsert `CachedSuiNSResolution(name:, address:, cachedAt: Date())`
6. Return the resolved address

### Errors

```swift
public enum SuiNSError: Error, LocalizedError {
    case invalidAddress(String)
    case invalidName(String)
    case nameNotFound(String)
    case rpc(SuiRPCError)
}
```

## 13. Image pipeline

### `IPFSGatewayResolver`

```swift
public struct IPFSGatewayResolver {
    public static let gateways: [String] = [
        "https://ipfs.io/ipfs/",
        "https://cloudflare-ipfs.com/ipfs/",
        "https://dweb.link/ipfs/",
    ]

    /// Given a remote URL string, returns ordered candidate URLs to try.
    /// - For `ipfs://<cid>` or `https://<gateway>/ipfs/<cid>`: returns [gateway1+cid, gateway2+cid, gateway3+cid]
    /// - For non-IPFS URLs: returns [originalURL]
    public func candidates(for url: String) -> [URL]
}
```

### `ImageDownloader`

```swift
public struct ImageDownloader {
    public let http: HTTPClient
    public let gateways: IPFSGatewayResolver

    public init(http: HTTPClient = .init(), gateways: IPFSGatewayResolver = .init())

    /// Tries each candidate in order, returns the first non-empty Data response.
    /// Throws `ImagePipelineError.allGatewaysFailed` if all candidates fail.
    public func download(remoteURL: String) async throws -> Data
}
```

### `ImageResizer`

```swift
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

public struct ImageResizer {
    /// Memory-efficient downsample via CGImageSourceCreateThumbnailAtIndex.
    /// Encodes to JPEG at quality 0.8 via CGImageDestination.
    public func resize(_ data: Data, maxPixelDimension: CGFloat) throws -> Data
}
```

Cross-platform via Core Graphics + ImageIO + UniformTypeIdentifiers (all available on iOS 14+/macOS 11+, well below the package's iOS 17 / macOS 14 minimum). No `UIImage` exposure means no `UIKit` import and no platform guards. Image pipeline tests run on both iOS and macOS — the macOS CI runner exercises the same resize logic the iOS app uses.

### `ImageCache` (actor)

```swift
public actor ImageCache {
    public init(containerURL: URL)                   // production: AppGroup; tests: temp dir

    public func store(_ data: Data, key: String) async throws -> URL
    public func url(forKey key: String) async -> URL?
    public func evict(key: String) async throws
    public func evictAll() async throws
}
```

Files live at `<containerURL>/Thumbnails/<key>.jpg`. Keys are pre-hashed by callers (so the cache itself is just a typed file store).

### `ThumbnailGenerator`

```swift
public struct ThumbnailGenerator {
    public let downloader: ImageDownloader
    public let resizer: ImageResizer
    public let cache: ImageCache

    public struct Result: Equatable {
        public let widgetURL: URL      // 200×200
        public let galleryURL: URL     // 600×600
    }

    public func generate(objectId: String, remoteURL: String) async throws -> Result
}
```

Key derivation: `SHA256(objectId + ":" + size).hexString` for each variant.

Flow:
1. `let data = try await downloader.download(remoteURL: remoteURL)` — handles IPFS rotation
2. Concurrent: `async let widgetData = resizer.resize(data, maxPixelDimension: 200)` and `async let galleryData = resizer.resize(data, maxPixelDimension: 600)`
3. Concurrent: store both under their keyed paths in `ImageCache`
4. Return `Result(widgetURL:, galleryURL:)`

### `ImagePipelineError`

```swift
public enum ImagePipelineError: Error, LocalizedError {
    case allGatewaysFailed(remoteURL: String)
    case decodeFailed
    case resizeFailed
    case writeFailed(underlying: Error)
}
```

## 14. Services layer

Each service is a `struct` with dependencies injected by initializer. No singletons. Services take an existing `ModelContext` rather than building their own — callers (app, integration tests) manage the lifecycle.

### `WalletService`

```swift
public struct WalletService {
    public let modelContext: ModelContext
    public let suiNS: SuiNSResolver

    public func add(addressOrName input: String, label: String? = nil) async throws -> Wallet
    public func list() async throws -> [Wallet]
    public func remove(id: UUID) async throws
    public func setPrimary(id: UUID) async throws
}
```

`add` resolves `name.sui` / `@name` via `suiNS`, validates `0x...` directly, persists a `Wallet` with `addedAt = Date()`.

### `PortfolioService` — the integration target

```swift
public struct PortfolioService {
    public let modelContext: ModelContext
    public let sui: SuiRPCClient
    public let coinGecko: CoinGeckoClient

    /// Cache-replacement refresh: deletes existing CachedPortfolio for the wallet
    /// (cascade clears children), inserts fresh.
    /// Returns the new CachedPortfolio with all token + stake + nft relationships populated.
    /// Stakes are fetched separately by StakingService; this method orchestrates token balances + prices only.
    /// Use `refreshAll(walletId:)` for the full refresh.
    public func refresh(walletId: UUID) async throws -> CachedPortfolio

    /// Full refresh: portfolio + stakes + NFTs in parallel via async let.
    public func refreshAll(walletId: UUID) async throws -> CachedPortfolio
}
```

`refresh(walletId:)` flow:
1. Load `Wallet` from `modelContext`; throw if not found
2. `sui.getAllBalances(owner: wallet.address)` → `[SuiBalance]`
3. `coinGecko.refreshCoinList()` (24h TTL — usually a cache hit)
4. Map each `SuiBalance.coinType` to a CoinGecko ID via `CachedCoinListEntry` lookup; mark `isTracked = false` for untracked
5. Batch-fetch prices for tracked coin types: `coinGecko.fetchPrices(coingeckoIds: ...)`
6. For untracked balances, optionally call `sui.getCoinMetadata(coinType:)` to populate `symbol`, `name`, `decimals` (so the UI can render them as "untracked but visible")
7. Compute portfolio totals + 24h change per CLAUDE.md formula:
   - `portfolio_today = Σ (balance/10^decimals × current_price)` for tracked tokens
   - `portfolio_yesterday = Σ (balance/10^decimals × yesterday_price)` where `yesterday_price = current_price / (1 + change_24h_percent / 100)`
   - `change_24h_usd = portfolio_today - portfolio_yesterday`
   - `change_24h_percent = (change_24h_usd / portfolio_yesterday) × 100`
8. Delete existing `CachedPortfolio` for `walletId`; cascade clears children
9. Insert new `CachedPortfolio(walletId:, totalUSD:, change24hUSD:, change24hPercent:, snapshotAt: Date(), tokens: [...])`
10. Save context, return

### `NFTService`

```swift
public struct NFTService {
    public let modelContext: ModelContext
    public let sui: SuiRPCClient
    public let thumbnails: ThumbnailGenerator?       // Optional: pass nil in CLI integration tests to skip thumbnail generation

    public func refresh(walletId: UUID) async throws -> [CachedNFTItem]
}
```

`refresh` flow:
1. Load `Wallet`; paginate `sui.getOwnedObjects(owner:, cursor:)` until `hasNextPage == false`
2. Parse `display` map for `name` and `image_url` per object
3. Upsert `CachedNFTItem` by `objectId` (unique). Existing rows preserve `showInWidget` flag.
4. For new NFTs with `imageURL`: spawn `Task.detached { try? await thumbnails?.generate(objectId:remoteURL:) }` so `refresh` returns fast; on completion, write `thumbnailFilePath` to the row
5. Return all NFTs for the wallet

### `StakingService`

```swift
public struct StakingService {
    public let modelContext: ModelContext
    public let sui: SuiRPCClient

    public func refresh(walletId: UUID) async throws -> [CachedStakePosition]
}
```

`refresh` flow:
1. `sui.getStakes(owner: wallet.address)` → array of `SuiDelegatedStake` (each contains a validator + list of stake entries)
2. For each unique validator address in results: if `CachedValidatorMetadata.cachedAt > 6h ago`, use cached; else fetch `sui.getLatestSuiSystemState()` once, extract matching validator info, upsert `CachedValidatorMetadata`
3. Flatten the stakes: one `CachedStakePosition` row per `(validator, stakeEntry)` pair, with validator name/image enriched from cache
4. Delete existing `CachedStakePosition` for `walletId`'s `CachedPortfolio`, insert fresh
5. Return the new rows

### `NewsService`

```swift
public struct NewsService {
    public let modelContext: ModelContext
    public let rss: RSSClient

    public func refresh() async throws -> [CachedNewsItem]
}
```

`refresh` flow:
1. TTL check: if `AppSettings.lastNewsFetchedAt > 30 min ago`, return persisted `CachedNewsItem` rows without network
2. `rss.fetchMerged(limit: 30)` → `[RawNewsItem]`
3. Upsert by `id` (which is `urlHash`); keep existing rows that aren't in the new batch only if they're still within the top 30 by date
4. Update `AppSettings.lastNewsFetchedAt = Date()`
5. Return current top-30 sorted

## 15. AppGroupStore async migration

Per Phase 0 prep #7. Migration steps:

```swift
// Before:
public func writeHandshake(_ value: String) throws { ... }
public func readHandshake() throws -> HandshakePayload? { ... }

// After:
public func writeHandshake(_ value: String) async throws { ... }
public func readHandshake() async throws -> HandshakePayload? { ... }
```

Implementation uses `Task.detached` to move file I/O off the calling actor:

```swift
public func writeHandshake(_ value: String) async throws {
    let url = handshakeURL
    let payload = HandshakePayload(value: value, writtenAt: Date())
    try await Task.detached(priority: .userInitiated) {
        let data = try JSONEncoder().encode(payload)
        try data.write(to: url, options: .atomic)
    }.value
}
```

Call site updates:
- `SuiWidget/App/ContentView.swift` — `writeAndReload()` becomes async; wrap in `Task { await writeAndReload() }` from `.onAppear`
- `SuiWidget/Widget/Provider/TimelineProvider.swift` — `currentEntry()` becomes async; `getTimeline` already takes a completion handler, wrap the async call in `Task`

Tests update: `AppGroupStoreTests` cases gain `async` keyword.

## 16. Test fixtures + recording

### Directory

`Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/Fixtures/` — every fixture is a raw response, no editing.

### Recording protocol (run once during plan execution)

Per-API recording commands (run from the repo root with curl). Each writes to the Fixtures directory. The chosen public test wallet is `<WALLET_ADDRESS>` — finalized during plan execution as a Mysten/Sui Foundation mainnet address with multi-token + NFT + stake holdings (verified via Suiscan or equivalent before recording).

Example commands (final list in the plan):
```bash
# Sui RPC
curl -s -X POST https://fullnode.mainnet.sui.io:443 \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"suix_getAllBalances","params":["<WALLET_ADDRESS>"]}' \
  > Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/Fixtures/sui-getAllBalances-success.json

# CoinGecko coin list (filter to platforms.sui exists)
curl -s 'https://api.coingecko.com/api/v3/coins/list?include_platform=true' \
  > Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/Fixtures/coingecko-coins-list-raw.json
# Then a script extracts entries with platforms.sui set, saves as coingecko-coins-list-sui-platform.json

# RSS feeds
curl -s https://blog.sui.io/rss.xml \
  > Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/Fixtures/rss-sui-blog.xml

# NFT thumbnail input — a small representative PNG
# Hand-authored 16x16 PNG via swift to ensure committed bytes are stable
```

Failure cases (HTTP 429, malformed JSON) — hand-authored synthetically to exercise error paths.

### `FixtureLoader`

```swift
struct FixtureLoader {
    static func data(named name: String) throws -> Data
    static func string(named name: String) throws -> String
    static func decoded<T: Decodable>(named name: String) throws -> T
}
```

Implementation uses `Bundle.module` (auto-generated by SwiftPM for `resources:` in the test target). Fixtures are declared in `Package.swift`:

```swift
.testTarget(
    name: "SuiWidgetKitTests",
    dependencies: ["SuiWidgetKit"],
    resources: [.process("Fixtures")]
)
```

### `MockHTTPClient`

```swift
struct MockHTTPClient: Sendable {
    typealias Response = (Data, HTTPURLResponse)
    var handler: @Sendable (URLRequest) async throws -> Response
}
```

`SuiRPCClient`, `CoinGeckoClient`, `RSSClient`, `ImageDownloader` are constructible with either a real `HTTPClient` or a protocol-erased mock — the cleanest path is making `HTTPClient` not the only option:

Actually simpler: `HTTPClient` is initialized with a `URLSession`, and tests use a `URLSession` configured with a `URLProtocol` subclass that returns prerecorded responses. This keeps the production code path identical to tests:

```swift
// In tests
let session = URLSession.testing(stubResponses: [
    URLRequest(url: someURL): try FixtureLoader.data(named: "sui-getAllBalances-success.json")
])
let client = SuiRPCClient(http: HTTPClient(session: session), rotator: .init(endpoints: [someURL]))
```

`URLSession.testing(stubResponses:)` is a test helper that registers a custom `URLProtocol` and returns a session. This is cleaner than a separate mock client because the production retry/backoff logic is exercised.

## 17. Live integration test

```swift
@Suite("Live integration", .disabled("hits real APIs; run manually via --filter"))
struct LiveIntegrationTests {
    @Test func portfolioRefresh_forKnownMainnetWallet() async throws {
        let testWallet = SuiAddress(rawValue: "<KNOWN_PUBLIC_MAINNET_ADDRESS>")!
        let container = try SwiftDataStack.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let walletId = UUID()
        context.insert(Wallet(id: walletId, address: testWallet.rawValue, isPrimary: true))
        try context.save()

        let service = PortfolioService(
            modelContext: context,
            sui: SuiRPCClient(),
            coinGecko: CoinGeckoClient(modelContext: context)
        )
        let portfolio = try await service.refreshAll(walletId: walletId)
        #expect(!portfolio.tokens.isEmpty)
        #expect(portfolio.totalUSD >= 0)
        print("PORTFOLIO: \(portfolio.tokens.count) tokens, total $\(portfolio.totalUSD)")
    }
}
```

Run manually: `swift test --package-path Packages/SuiWidgetKit --filter "Live integration"`. Not run in CI.

## 18. Bootstrap execution order (preview of the plan)

1. **Phase 0 prep refactors** — models, schema, AppGroupStore async migration, ContentView/widget call-site updates (one commit per concern)
2. **HTTPClient + HTTPClientError + tests** — fixtures: 429 response, success response
3. **RPCEndpointRotator (actor) + tests** — uses injectable clock for deterministic timing
4. **SuiRPCClient + SuiRPCTypes + SuiRPCError + tests** — fixtures: all 7 method success responses
5. **CoinGeckoClient + types + tests** — fixtures: coin list (filtered), markets batch
6. **FeedKit dependency + RSSClient + tests** — fixtures: blog RSS, releases Atom
7. **SuiNSResolver + tests** — fixtures: resolve success, resolve missing, reverse
8. **Image pipeline** (IPFSGatewayResolver, ImageDownloader, ImageResizer, ImageCache, ThumbnailGenerator) + tests — fixtures: small PNG
9. **Services** (WalletService, PortfolioService, NFTService, StakingService, NewsService) + tests — uses prior fixtures via service-level mocks
10. **Live integration test** (disabled) + final fixture recording + CLAUDE.md edits (Quest field) + README updates
11. **CI workflow tweaks** — add `needs: package-tests` gate to `ios-build` (Phase 0 prep #9)

Estimated ~40-50 bite-sized tasks. Each step ends with a focused commit; per-task commits authorized.

## 19. Open items deferred to Phase 2+

- BGTaskScheduler registration (`io.sui.widget.refresh`, `io.sui.widget.cleanup`, `io.sui.widget.coinlist`) — wired in `AppDelegate` during Phase 2
- `Info.plist` `BGTaskSchedulerPermittedIdentifiers` entries — added in Phase 2
- WidgetCenter reload triggers from cache updates — Phase 2 UI layer responsibility
- Feature flag mechanism for Quest list — Phase 3 (V3 hook polish)
- Localization scaffolding — Phase 4
- Snapshot tests for widget rendering — Phase 3
- Pin XcodeGen version in CI — minor follow-up; deferred (low risk)
- Update README's "Bootstrap" section about regenerating `.xcodeproj` — defer (low risk)
- Remove redundant `*.xcuserdatad` from `.gitignore` — defer (cosmetic)
- Surface `SuiWidgetKit.version` constant or delete — defer (cosmetic)
