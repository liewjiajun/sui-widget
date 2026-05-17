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
