import Foundation
import SwiftData
import Testing
@testable import SuiWidgetKit

@Suite("SwiftDataStack")
struct SwiftDataStackTests {

    @Test("in-memory container initializes with the populated schema")
    func inMemoryContainerInitializes() throws {
        let container = try SwiftDataStack.makeContainer(inMemory: true)
        #expect(container.schema.entities.count == 13)
    }

    @Test("schema lists exactly the expected entity names alphabetically")
    func schemaListsExpectedEntities() {
        let names = SwiftDataStack.schema.entities.map { $0.name }.sorted()
        #expect(names == [
            "ActivityEvent",
            "AppSettings",
            "CachedCoinListEntry",
            "CachedNFTItem",
            "CachedNewsItem",
            "CachedPortfolio",
            "CachedStakePosition",
            "CachedSuiNSResolution",
            "CachedTokenHolding",
            "CachedValidatorMetadata",
            "Pet",
            "Quest",
            "Wallet",
        ])
    }

    @Test("can insert, save, and fetch a Wallet through the in-memory container")
    func walletInsertAndFetchRoundTrip() throws {
        let container = try SwiftDataStack.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let id = UUID()
        let wallet = Wallet(
            id: id,
            address: "0x" + String(repeating: "a", count: 64),
            label: "Test",
            isPrimary: true
        )
        context.insert(wallet)
        try context.save()

        let descriptor = FetchDescriptor<Wallet>(predicate: #Predicate { $0.id == id })
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.label == "Test")
        #expect(fetched.first?.isPrimary == true)
    }

    @Test("AppSettings has at most one row even after duplicate inserts")
    func appSettingsSingletonEnforced() throws {
        let container = try SwiftDataStack.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(AppSettings())
        try? context.save()
        context.insert(AppSettings())
        try? context.save()

        let all = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(all.count == 1)
    }
}
