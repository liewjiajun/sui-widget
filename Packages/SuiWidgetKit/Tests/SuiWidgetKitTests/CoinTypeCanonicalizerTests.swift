import Testing
@testable import SuiWidgetKit

@Suite("CoinTypeCanonicalizer")
struct CoinTypeCanonicalizerTests {
    @Test func canonicalizes_short_form_sui() {
        let canonical = CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI")
        #expect(canonical == "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI")
    }

    @Test func leaves_long_form_unchanged() {
        let input = "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
        #expect(CoinTypeCanonicalizer.canonicalize(input) == input)
    }

    @Test func lowercases_hex() {
        let canonical = CoinTypeCanonicalizer.canonicalize("0xABC::test::T")
        #expect(canonical == "0x0000000000000000000000000000000000000000000000000000000000000abc::test::T")
    }

    @Test func areEquivalent_matches_short_and_long_form() {
        #expect(CoinTypeCanonicalizer.areEquivalent("0x2::sui::SUI",
            "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"))
    }

    @Test func leaves_unparseable_input_alone() {
        #expect(CoinTypeCanonicalizer.canonicalize("not::a::coin::type") == "not::a::coin::type")
    }
}
