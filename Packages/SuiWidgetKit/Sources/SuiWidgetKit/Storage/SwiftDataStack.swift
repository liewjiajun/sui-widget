import Foundation
import SwiftData

/// Owns the shared `ModelContainer` used by both the main app and the widget extension.
///
/// The schema registers all entities the V1 data layer persists, plus the V2
/// (`Pet`) and V3 (`Quest`, `ActivityEvent`) stubs so future versions ship
/// without schema migration. The in-memory variant (`makeContainer(inMemory: true)`)
/// skips the App Group container path and is safe to call from unit tests; the
/// production variant binds the store to `group.io.sui.widget` so the widget
/// extension reads the same database.
public enum SwiftDataStack {

    /// All persistent entities. Order is alphabetical so future additions produce
    /// minimal diff churn.
    public static let schema = Schema([
        ActivityEvent.self,
        AppSettings.self,
        CachedCoinListEntry.self,
        CachedNFTItem.self,
        CachedNewsItem.self,
        CachedPortfolio.self,
        CachedPriceHistory.self,
        CachedStakePosition.self,
        CachedSuiNSResolution.self,
        CachedSuiNSReverse.self,
        CachedTokenHolding.self,
        CachedValidatorMetadata.self,
        Pet.self,
        Quest.self,
        Wallet.self,
    ])

    /// On-disk store name. Stable across versions so SwiftData migration paths
    /// remain valid.
    private static let storeName = "SuiWidget"

    /// Builds the `ModelContainer`. Production callers use the default
    /// (`inMemory: false`) to get the App Group-backed container. Test callers
    /// may pass `inMemory: true` to avoid touching the file system.
    ///
    /// - Warning: Calling with `inMemory: false` outside an entitled target
    ///   throws a SwiftData error because the App Group container resolves to nil.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else if FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupStore.groupIdentifier
        ) != nil {
            // App Group entitlement present — bind the store to the shared
            // container so the widget extension reads the same database.
            configuration = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(AppGroupStore.groupIdentifier)
            )
        } else {
            // App Group container is unavailable (e.g. the entitlement was
            // stripped in an unsigned / `CODE_SIGNING_ALLOWED=NO` build, or
            // misconfigured). Passing `.groupContainer` here makes SwiftData
            // call `fatalError` deep inside `ModelContainer.init` — which a
            // `try?`/`do-catch` cannot recover from — so the app would hard
            // crash on launch. Fall back to a private on-disk store instead:
            // the app still launches, and the widget simply sees an empty store
            // (correct degradation rather than a crash).
            configuration = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
