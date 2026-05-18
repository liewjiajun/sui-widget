import Foundation
import SwiftData

/// Owns the shared `ModelContainer` used by both the main app and the widget extension.
///
/// Phase 1 registers all entities the data layer persists. The in-memory variant
/// (`makeContainer(inMemory: true)`) skips the App Group container path and is safe
/// to call from unit tests; the production variant binds the store to
/// `group.io.sui.widget` so the widget extension reads the same database.
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
        CachedStakePosition.self,
        CachedSuiNSResolution.self,
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
        } else {
            configuration = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(AppGroupStore.groupIdentifier)
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
