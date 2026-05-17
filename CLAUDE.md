# Sui Widget — Technical Brief

## Project overview

A free, native iOS app that displays a Sui user's portfolio, NFTs, staking positions, and ecosystem news on Home Screen and Lock Screen widgets. V1 is fully serverless, read-only, no auth, no monetization.

V2 will add a soul-bound pixel pet NFT minted via Move contract. V3 will add quests and XP. V1 must scaffold hooks for V2 and V3 without implementing them.

## Locked decisions

| Decision | Value |
|---|---|
| Platform | iOS 17.0 minimum |
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Widget framework | WidgetKit |
| Local storage | SwiftData |
| Concurrency | Swift async/await |
| Backend | None for V1 |
| Auth | None for V1 |
| Network | URLSession with async/await |
| Sui SDK | Direct JSON-RPC, no SDK dependency |
| RSS parser | FeedKit (Swift package) |
| Image loading | Nuke or custom URLSession-based, no AlamoFire |
| Monetization | None |

## Architecture

```
iOS App Bundle
├── Main App Target
│    ├── UI Layer (SwiftUI views)
│    ├── ViewModels (ObservableObject)
│    └── Services (use Shared framework)
│
├── Widget Extension Target
│    ├── TimelineProvider
│    ├── Widget views (SwiftUI)
│    └── Reads from App Group container
│
└── SuiWidgetKit (Shared framework / Swift package)
     ├── Models
     ├── Networking (Sui RPC, CoinGecko, RSS)
     ├── Storage (App Group, SwiftData, image cache)
     └── Services (Portfolio, NFT, Staking, News, Wallet)

External services (direct HTTPS, no server):
├── Sui RPC (Mysten public + fallbacks)
├── CoinGecko API (free tier, no key)
├── Sui blog RSS (https://blog.sui.io/rss.xml)
└── GitHub releases Atom feed
```

## Project structure

```
SuiWidget/
├── App/
│   ├── SuiWidgetApp.swift
│   ├── AppDelegate.swift
│   ├── ContentView.swift
│   └── Features/
│       ├── Onboarding/
│       ├── WalletManagement/
│       ├── Portfolio/
│       ├── NFTGallery/
│       ├── News/
│       ├── WidgetConfig/
│       └── Settings/
├── Widget/
│   ├── SuiWidgetBundle.swift
│   ├── Provider/
│   │   ├── TimelineProvider.swift
│   │   └── WidgetEntry.swift
│   ├── LockScreen/
│   │   ├── CircularWidgetView.swift
│   │   ├── RectangularWidgetView.swift
│   │   └── InlineWidgetView.swift
│   └── HomeScreen/
│       ├── SmallWidgetView.swift
│       ├── MediumWidgetView.swift
│       ├── LargeWidgetView.swift
│       └── ExtraLargeWidgetView.swift
├── SuiWidgetKit/
│   ├── Models/
│   │   ├── Wallet.swift
│   │   ├── TokenHolding.swift
│   │   ├── PortfolioSnapshot.swift
│   │   ├── StakePosition.swift
│   │   ├── NFTItem.swift
│   │   ├── NewsItem.swift
│   │   └── (V2 stubs) Pet.swift, Quest.swift
│   ├── Networking/
│   │   ├── SuiRPCClient.swift
│   │   ├── CoinGeckoClient.swift
│   │   ├── RSSClient.swift
│   │   └── RPCEndpointRotator.swift
│   ├── Storage/
│   │   ├── AppGroupStore.swift
│   │   ├── SwiftDataStack.swift
│   │   ├── ImageCache.swift
│   │   └── ThumbnailGenerator.swift
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
└── Tests/
    ├── SuiWidgetKitTests/
    └── UITests/
```

## Data models (SwiftData entities)

```swift
@Model
final class Wallet {
    @Attribute(.unique) var id: UUID
    var address: String          // 0x-prefixed, 32 bytes
    var label: String?
    var suiNSName: String?       // resolved .sui or @ name
    var addedAt: Date
    var isPrimary: Bool
    var orderIndex: Int
}

@Model
final class CachedPortfolio {
    @Attribute(.unique) var walletId: UUID  // or sentinel for aggregate
    var totalUSD: Decimal
    var change24hUSD: Decimal
    var change24hPercent: Double
    var snapshotAt: Date
    @Relationship var tokens: [CachedTokenHolding]
    @Relationship var stakes: [CachedStakePosition]
    @Relationship var nfts: [CachedNFTItem]
}

@Model
final class CachedTokenHolding {
    var coinType: String         // e.g. 0x2::sui::SUI
    var symbol: String
    var name: String
    var balance: Decimal
    var decimals: Int
    var priceUSD: Decimal?
    var priceChange24h: Double?
    var iconURL: String?
    var isTracked: Bool          // false if not on CoinGecko
}

@Model
final class CachedStakePosition {
    var validatorAddress: String
    var validatorName: String?
    var validatorImageURL: String?
    var principal: Decimal       // in SUI base units
    var estimatedReward: Decimal
    var status: String           // "active", "pending", "withdrawing"
    var stakingPool: String
}

@Model
final class CachedNFTItem {
    var objectId: String
    var collectionName: String?
    var name: String
    var imageURL: String
    var thumbnailFilePath: String?  // file in App Group
    var showInWidget: Bool
    var attributes: [String: String]
}

@Model
final class CachedNewsItem {
    @Attribute(.unique) var id: String  // hash of URL
    var title: String
    var url: String
    var publishedAt: Date
    var source: String           // "blog", "github_release"
    var summary: String?
}

@Model
final class AppSettings {
    var defaultCurrency: String = "USD"
    var theme: String = "system"
    var refreshFrequencyMinutes: Int = 30
    var showUntrackedTokens: Bool = true
    var notificationsEnabled: Bool = false
}

// V2 stubs — schema reserved, not yet active
@Model
final class Pet {
    @Attribute(.unique) var objectId: String
    var walletAddress: String
    var seed: String             // deterministic seed
    var level: Int
    var xp: Int
    var traits: [String: String]
    var spriteFilePath: String?
    var hatchedAt: Date
}

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

## API integrations

### Sui RPC

| Method | Use |
|---|---|
| `suix_getAllBalances` | Token balances per wallet |
| `suix_getCoinMetadata` | Token symbol, decimals, icon |
| `suix_getOwnedObjects` | NFT enumeration with display fields |
| `suix_getStakes` | Active stake positions per wallet |
| `suix_getLatestSuiSystemState` | Validator metadata |
| `suix_resolveNameServiceAddress` | Resolve .sui / @ to 0x... |
| `suix_resolveNameServiceNames` | Reverse lookup |

**Endpoint rotation:**

```swift
let endpoints = [
    "https://fullnode.mainnet.sui.io:443",
    "https://sui-mainnet.public.blastapi.io",
    "https://sui-mainnet-rpc.allthatnode.com",
]
```

Failover logic: try in order, on HTTP 429 or 5xx or timeout >5s, advance to next. Track failure count per endpoint in memory, reset every 5 min.

### CoinGecko

| Endpoint | Use | Cache TTL |
|---|---|---|
| `/coins/list?include_platform=true` | Map Sui coin type to CoinGecko ID. Filter where `platforms.sui` exists | 24 hours |
| `/coins/markets?vs_currency=usd&ids=...` | Current price + 24h change for held tokens | 5 minutes |

**Token coverage approach:**

On launch or daily refresh, fetch `/coins/list` and build a map `[suiCoinType: coingeckoId]`. When user holds a token, look up the CoinGecko ID. If not present, mark `isTracked = false` and show under "untracked" in UI.

24h change calculation:

```
yesterday_price = current_price / (1 + change_24h_percent / 100)
portfolio_today = Σ (balance × current_price) for all tracked tokens
portfolio_yesterday = Σ (balance × yesterday_price) for all tracked tokens
portfolio_change_24h_usd = portfolio_today - portfolio_yesterday
portfolio_change_24h_percent = (portfolio_change_24h_usd / portfolio_yesterday) × 100
```

Untracked tokens contribute zero to portfolio value.

### RSS feeds

| Source | URL |
|---|---|
| Sui blog | `https://blog.sui.io/rss.xml` |
| GitHub releases | `https://github.com/MystenLabs/sui/releases.atom` |

Fetch both, merge, sort by date, dedupe by URL hash, keep last 30 items.

## Caching strategy

| Data type | TTL | Where |
|---|---|---|
| Token balances | 5 min | SwiftData + App Group |
| Token prices | 5 min | SwiftData + App Group |
| NFT object list | 15 min | SwiftData + App Group |
| NFT thumbnails | Forever (manual eviction) | App Group file container |
| Stake positions | 5 min | SwiftData + App Group |
| Validator metadata | 6 hours | SwiftData |
| SuiNS resolution | 1 hour | SwiftData |
| News feed | 30 min | SwiftData |
| CoinGecko coin list | 24 hours | SwiftData |

On widget timeline provider call, read from App Group container only. Do not block on network. If cache is stale, trigger background refresh, return stale data with stale flag.

## Widget refresh strategy

| Trigger | Mechanism |
|---|---|
| App foreground | Refresh immediately on launch |
| Wallet added or removed | Refresh immediately |
| Background app refresh | `BGAppRefreshTask` scheduled every 30 min (system decides actual interval) |
| Widget timeline expiry | Provider returns next timeline entry +30 min from now |
| Pull-to-refresh in app | Manual refresh, no rate limit |

Widget extension itself can perform network calls if cache is too stale and a refresh is critical. Default behavior: read cache only.

## Image pipeline

Critical for widget performance. NFT images are large, widget memory budget is 30MB.

1. NFT object discovered with image URL (often IPFS)
2. Main app rewrites IPFS URL: try `https://ipfs.io/ipfs/{cid}`, fall back to `https://cloudflare-ipfs.com/ipfs/{cid}`, then `https://dweb.link/ipfs/{cid}`
3. Download full image
4. Resize to 200×200 (widget) and 600×600 (in-app gallery) using `ImageIO`
5. Save thumbnails to App Group container as JPEG (quality 0.8)
6. Store file path in SwiftData
7. Widget reads file from disk, no network call

Eviction: when NFT removed from "show in widget" set or wallet removed, delete thumbnail. Run weekly cleanup of orphaned files.

## SuiNS resolution

Accept three formats:

| Input | Treatment |
|---|---|
| `0x` + 64 hex chars | Direct, validate checksum |
| `name.sui` | Call `suix_resolveNameServiceAddress` |
| `@name` | Treat as `name.sui` and resolve |

Display rule: if address has a resolved SuiNS name, show name with address as tooltip. Otherwise show truncated address `0x12ab...cd34`.

## Background tasks

| Task | Identifier | Schedule |
|---|---|---|
| Portfolio refresh | `io.sui.widget.refresh` | Every 30 min (BGAppRefreshTask) |
| Image cache cleanup | `io.sui.widget.cleanup` | Weekly (BGProcessingTask) |
| Coin list update | `io.sui.widget.coinlist` | Daily (BGAppRefreshTask) |

Register in `Info.plist`. Implement in `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`.

## V2 hooks to scaffold in V1

| Hook | Implementation |
|---|---|
| Pet sprite style | **Locked: sea creature pixel art**, 32×32 or 64×64 sprite. Generation algorithm assembles trait layers (body, color, accessories, expression) deterministically from seed bytes. Layer assets sourced from V1 design deliverables |
| Pet SwiftData model | Created in V1, never written to |
| Pet view placeholder | "Pet feature coming soon" screen in app, deep-linkable from widget slot |
| Pet seed scheme | **Locked:** `keccak256(walletAddress + "::pet::v1")` returns 32 bytes used as deterministic seed for trait generation. This is a one-way commitment: changing it later breaks all previously hatched pets. **Design implication: one pet per wallet, forever.** Soul-bound enforcement at the Move contract level prevents transfer, so the deterministic seed never produces conflicts |
| Soul-bound enforcement | Move contract exposes `mint` but no `transfer` function. Pet struct lacks `store` ability or uses `key` only, preventing wrapping or transfer. Must be validated in contract review before mainnet deploy |
| Move package address reservation | Generate keypair, deploy empty package on devnet, reserve mainnet address for V2 |
| Move module names | Lock: `pet::pet`, `pet::generation`, `pet::traits` |
| Pet slot in widget layouts | Conditional rendering: if pet exists in cache, show; else show "Hatch a pet" CTA |
| Wallet signing infrastructure | Plan WalletConnect or Sui deeplink integration, do not build in V1 |

## V3 hooks to scaffold in V1

| Hook | Implementation |
|---|---|
| Quest SwiftData model | Created in V1, never written to |
| Event log | Add empty `ActivityEvent` model to log wallet syncs, useful for retroactive quest verification |
| XP storage | Field on Pet model, defaults to 0 |
| Quest list screen | Hidden behind feature flag, ready to enable |

## Phased milestones

### Phase 0: Project setup (Week 1)

- Xcode project with app target, widget extension, shared Swift package
- App Group entitlement configured
- SwiftData stack initialized
- Design system imported from Figma
- CI: GitHub Actions running `swift test` and `xcodebuild`

**Acceptance:** App launches, widget extension installs, both can read/write a test value to App Group.

### Phase 1: Data layer (Weeks 2-3)

- `SuiRPCClient` with endpoint rotation and error handling
- `CoinGeckoClient` with coin list caching and price fetching
- `RSSClient` for blog + GitHub releases
- `SuiNSResolver`
- Image pipeline with IPFS gateway rotation, resize, App Group storage
- Unit tests for each client and parser

**Acceptance:** Given a test wallet address, fetch and cache balances, NFTs, stakes, prices, news. All readable via shared framework.

### Phase 2: Main app UI (Weeks 4-5)

- Onboarding flow
- Wallet management (add, list, edit, remove)
- Portfolio view (aggregate + per-wallet)
- NFT gallery with show-in-widget toggle
- News feed with in-app browser
- Settings

**Acceptance:** All screens navigable, all data sourced from data layer, dark and light mode pass design review.

### Phase 3: Widgets (Weeks 6-7)

- Timeline provider with App Group reads
- All Lock Screen sizes (circular, rectangular, inline)
- All Home Screen sizes (small, medium, large, XL)
- Display variants per size (portfolio / NFT / news)
- Widget configurator in app
- Deep linking from widget tap

**Acceptance:** All widget sizes render with real data, refresh on schedule, configurator works.

### Phase 4: Polish and beta (Weeks 8-9)

- Error handling pass: every async path
- Loading and empty states per design spec
- Localization scaffolding (English only ships)
- Accessibility audit: VoiceOver, dynamic type, contrast
- TestFlight build, beta with Sui community

**Acceptance:** App passes Apple review checklist, no critical bugs in beta after 1 week.

## Testing approach

| Layer | Tests |
|---|---|
| RPC clients | Unit tests with recorded JSON fixtures, no live network in CI |
| CoinGecko client | Same as above |
| RSS parser | Fixture-based |
| Portfolio calculation | Pure function tests with known balances and prices |
| Image pipeline | Test resize quality, IPFS gateway fallback |
| Widget rendering | Snapshot tests for each size in light + dark mode |
| UI flows | XCUITest for onboarding, wallet add, NFT toggle |

## Out of scope V1

| Excluded | Why |
|---|---|
| Server / backend | Serverless V1 |
| Push notifications for price alerts | Requires server |
| Cross-device sync | Requires server |
| Wallet signing or transactions | Read-only V1 |
| Custom RPC endpoint configuration | Forced default |
| Pet hatching | V2 |
| Quests | V3 |
| Analytics | V2 consideration |
| iCloud backup of wallet list | V2 consideration |

## Open technical questions

1. CoinGecko free tier rate limit: 10-30 calls/min depending on conditions. With 1 batched call per refresh per user, this is fine until ~5k concurrent active users. If hit, evaluate pro tier or switch to Pyth Hermes as primary
2. IPFS gateway reliability: monitor 95th percentile load time in beta, add more gateways if needed
3. SuiNS resolution for `@` prefix format: confirm exact RPC method (may need `suix_resolveNameServiceNames` or different format)
4. Widget tap deep linking: design URL scheme `suiwidget://wallet/{id}`, `suiwidget://nft/{objectId}`, `suiwidget://news/{itemId}`

## Reference materials

| Resource | URL |
|---|---|
| Sui JSON-RPC docs | https://docs.sui.io/sui-api-ref |
| WidgetKit docs | https://developer.apple.com/documentation/widgetkit |
| SwiftData docs | https://developer.apple.com/documentation/swiftdata |
| CoinGecko API | https://www.coingecko.com/en/api/documentation |
| FeedKit | https://github.com/nmdias/FeedKit |
| SuiNS | https://docs.suins.io/ |
