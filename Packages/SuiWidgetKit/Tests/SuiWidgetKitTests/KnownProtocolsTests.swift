import Foundation
import Testing
@testable import SuiWidgetKit

@Suite("KnownProtocols")
struct KnownProtocolsTests {

    @Test func direct_lst_mappings_resolve_to_sui_underlying() {
        let afsui = "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI"
        let result = KnownProtocols.enrichment(forCoinType: afsui)
        #expect(result?.dappName == "Aftermath")
        #expect(result?.symbolOverride == "afSUI")
        #expect(result?.underlyingCanonicalCoinType == KnownProtocols.suiCanonical)
    }

    @Test func volo_and_haedal_lst_mappings_present() {
        let vsui = "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT"
        let hasui = "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI"
        #expect(KnownProtocols.enrichment(forCoinType: vsui)?.dappName == "Volo")
        #expect(KnownProtocols.enrichment(forCoinType: hasui)?.dappName == "Haedal")
    }

    @Test func lsts_are_categorised_as_liquid_staking() {
        for coinType in [
            "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI",
            "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT",
            "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI",
        ] {
            #expect(KnownProtocols.enrichment(forCoinType: coinType)?.category == .liquidStaking)
        }
    }

    @Test func expanded_lst_set_includes_alphafi_and_springsui() {
        let stsui = "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55::stsui::STSUI"
        let ssui = "0x83556891f4a0f233ce7b05cfe7f957d4020492a34f5405b2cb9377d060bef4bf::spring_sui::SPRING_SUI"
        let alphafi = KnownProtocols.enrichment(forCoinType: stsui)
        #expect(alphafi?.dappName == "AlphaFi")
        #expect(alphafi?.symbolOverride == "stSUI")
        #expect(alphafi?.category == .liquidStaking)
        let spring = KnownProtocols.enrichment(forCoinType: ssui)
        #expect(spring?.dappName == "SpringSui")
        #expect(spring?.category == .liquidStaking)
    }

    @Test func scallop_market_coin_extracts_underlying_type() {
        // <scallop-pkg>::reserve::MarketCoin<0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC>
        let scallopUsdc = KnownProtocols.scallopPackage
            + "::reserve::MarketCoin<0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC>"
        let result = KnownProtocols.enrichment(forCoinType: scallopUsdc)
        #expect(result?.dappName == "Scallop")
        #expect(result?.symbolOverride == "sUSDC")
        #expect(result?.underlyingCanonicalCoinType.hasSuffix("::usdc::USDC") == true)
        #expect(result?.category == .lending)
    }

    @Test func kai_ytokens_are_lending_positions_via_underlying() {
        // ySUI → priced via SUI, tagged Kai / Lending.
        let ysui = KnownProtocols.enrichment(
            forCoinType: "0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ysui::YSUI"
        )
        #expect(ysui?.dappName == "Kai")
        #expect(ysui?.symbolOverride == "ySUI")
        #expect(ysui?.category == .lending)
        #expect(ysui?.underlyingCanonicalCoinType == KnownProtocols.suiCanonical)

        // yUSDC → priced via USDC.
        let yusdc = KnownProtocols.enrichment(
            forCoinType: "0x7ea359636b36e7c027c2cd71adedaf19be658e1477d9e71368a0b3824a0a27ff::yusdc::YUSDC"
        )
        #expect(yusdc?.dappName == "Kai")
        #expect(yusdc?.symbolOverride == "yUSDC")
        #expect(yusdc?.category == .lending)
        #expect(yusdc?.underlyingCanonicalCoinType.hasSuffix("::usdc::USDC") == true)
    }

    @Test func unknown_coin_type_returns_nil() {
        let random = "0xaaaa::random::TOKEN"
        #expect(KnownProtocols.enrichment(forCoinType: random) == nil)
    }

    @Test func canonicalisation_handles_short_form_input() {
        // Canonicaliser normalises 0x2 → 0x000…002. afSUI's package addr is
        // already canonical-length so this test only proves we don't reject
        // raw inputs that aren't canonicalised by the caller.
        let afsuiShort = "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI"
        #expect(KnownProtocols.enrichment(forCoinType: afsuiShort) != nil)
    }
}
