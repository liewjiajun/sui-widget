import Foundation
import Testing
@testable import SuiWidgetKit

@Suite("CollectionNamer")
struct CollectionNamerTests {

    @Test func prefers_display_collection_field_when_present() {
        let name = CollectionNamer.collectionName(
            displayCollection: "Prime Machin",
            type: "0xabc::factory::PrimeMachin"
        )
        #expect(name == "Prime Machin")
    }

    @Test func empty_display_collection_falls_back_to_type() {
        let name = CollectionNamer.collectionName(
            displayCollection: "  ",
            type: "0xabc::factory::PrimeMachin"
        )
        #expect(name == "Prime Machin")
    }

    @Test func humanises_pascal_case_struct_name() {
        // The reported bug: raw package IDs shown instead of a readable name.
        let name = CollectionNamer.collectionName(
            displayCollection: nil,
            type: "0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0::suins_registration::SuinsRegistration"
        )
        #expect(name == "Suins Registration")
    }

    @Test func humanises_snake_case_struct_name() {
        let name = CollectionNamer.collectionName(
            displayCollection: nil,
            type: "0xabc::module::cool_cats"
        )
        #expect(name == "Cool Cats")
    }

    @Test func keeps_acronyms_uppercase() {
        #expect(CollectionNamer.humanise("NFT") == "NFT")
        #expect(CollectionNamer.humanise("cool_NFT_thing") == "Cool NFT Thing")
    }

    @Test func unwraps_coin_generic_to_inner_type() {
        let name = CollectionNamer.collectionName(
            displayCollection: nil,
            type: "0x2::coin::Coin<0xabc::widget::SuperWidget>"
        )
        #expect(name == "Super Widget")
    }

    @Test func nil_type_and_no_display_is_uncategorized() {
        #expect(CollectionNamer.collectionName(displayCollection: nil, type: nil) == "Uncategorized")
    }

    @Test func never_returns_a_raw_package_id() {
        // Regression guard for the exact symptom the user reported.
        let name = CollectionNamer.collectionName(
            displayCollection: nil,
            type: "0x60e688bb4071cd6ea5aed6f22b2dc717e067bbcbe60b73c931a0be728c3cfb75::whitelist::Whitelist"
        )
        #expect(!name.contains("0x"))
        #expect(!name.contains("::"))
        #expect(name == "Whitelist")
    }
}
