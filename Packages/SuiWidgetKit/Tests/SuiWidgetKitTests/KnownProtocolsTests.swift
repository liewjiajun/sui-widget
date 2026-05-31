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

    /// Regression guard for the verification gap that mislabeled plain assets as
    /// DeFi positions: a base/spendable asset must NEVER enrich. If this fails, a
    /// user's plain SUI / USDC / WAL / DEEP / SCA / BUCK would be tagged as a
    /// (wrongly-priced) protocol position.
    @Test func base_assets_never_enrich_as_defi_positions() {
        let bases = [
            "0x2::sui::SUI",
            "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
            "0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL",
            "0xdeeb7a4662eec9f2f3def03fb937a663dddaa2e215b8078a284d026b7946c270::deep::DEEP",
            "0x7016aae72cfc67f2fadf55769c0a7dd54291a583b63051a5ed71081cce836ac6::sca::SCA",
            "0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::buck::BUCK",
        ]
        for base in bases {
            #expect(KnownProtocols.enrichment(forCoinType: base) == nil,
                    "base asset \(base) must not be tagged as a DeFi position")
        }
    }

    /// The expanded registry carries broad, non-trivial coverage. Lower bound
    /// only, so adding protocols never breaks the test.
    @Test func registry_has_broad_coverage() {
        #expect(KnownProtocols.registeredCoinTypeCount >= 45)
    }

    /// Spot-checks across newly-added protocols: each enriches with the right
    /// dapp + category, and its underlying differs from its own coin type.
    @Test func new_protocols_enrich_correctly() {
        struct Case { let ct: String; let dapp: String; let cat: KnownProtocols.Category }
        let cases = [
            // Scallop newer standalone sCoin (not the legacy MarketCoin form).
            Case(ct: "0xaafc4f740de0dd0dde642a31148fb94517087052f19afb0f7bed1dc41a50c77b::scallop_sui::SCALLOP_SUI", dapp: "Scallop", cat: .lending),
            // AlphaFi SuperSUI (basket LST).
            Case(ct: "0x790f258062909e3a0ffc78b3c53ac2f62d7084c3bab95644bdeb05add7250001::super_sui::SUPER_SUI", dapp: "AlphaFi", cat: .liquidStaking),
            // Walrus liquid-staked WAL.
            Case(ct: "0xb1b0650a8862e30e3f604fd6c5838bc25464b8d3d827fbd58af7cb9685b832bf::wwal::WWAL", dapp: "Walrus", cat: .liquidStaking),
        ]
        for c in cases {
            guard let e = KnownProtocols.enrichment(forCoinType: c.ct) else {
                #expect(Bool(false), "expected enrichment for \(c.ct)")
                continue
            }
            #expect(e.dappName == c.dapp, "\(c.ct) dapp \(e.dappName) != \(c.dapp)")
            #expect(e.category == c.cat)
            #expect(CoinTypeCanonicalizer.canonicalize(c.ct) != e.underlyingCanonicalCoinType,
                    "receipt must not be its own underlying: \(c.ct)")
        }
    }

    /// Regression for the wrong-Kai-amount bug: enrichment must carry the
    /// receipt's OWN live-verified decimals, so PortfolioService never falls back
    /// to the metadata RPC (which defaults to 9 under rate-limiting). A 6-decimal
    /// yToken shown at 9 decimals reads 1000x too small.
    @Test func registry_entries_carry_verified_decimals() {
        // 6-decimal Kai yTokens (the ones that broke at the default 9).
        for ct in [
            "0x7ea359636b36e7c027c2cd71adedaf19be658e1477d9e71368a0b3824a0a27ff::yusdc::YUSDC",
            "0x36bc697c1dba827a4bf7fa3bfc9f1b0953fe09b91c4b4c103efa0b086e03d923::ysuiusdt::YSUIUSDT",
            "0xdd7108db1a209d23d8a25dda78bdca4547b755094305971ed4064dfe5cdfa026::yusdy::YUSDY",
            "0x5b2fa5c76309a417ccd14a65f036b8d1ff4e76a143ed878a47fdecfe0b09860e::ydeep::YDEEP",
        ] {
            #expect(KnownProtocols.enrichment(forCoinType: ct)?.decimals == 6, "expected 6 decimals for \(ct)")
        }
        // 8-decimal BTC yTokens.
        for ct in [
            "0xfc39a879b5a8772f682f1202cc5a8a3d93654cbb9e716b96bda7e5832af0e0eb::yxbtc::YXBTC",
            "0x3e83d9c798902dbcde72b9ede9fa2997ea43b302f83e4894aa793e6791e95c9f::ylbtc::YLBTC",
        ] {
            #expect(KnownProtocols.enrichment(forCoinType: ct)?.decimals == 8, "expected 8 decimals for \(ct)")
        }
        // 9-decimal SUI-vault receipt / SUI-LST.
        #expect(KnownProtocols.enrichment(forCoinType: "0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ysui::YSUI")?.decimals == 9)
        #expect(KnownProtocols.enrichment(forCoinType: "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI")?.decimals == 9)
        // Scallop standalone sUSDC is 6-decimal.
        #expect(KnownProtocols.enrichment(forCoinType: "0x854950aa624b1df59fe64e630b2ba7c550642e9342267a33061d59fb31582da5::scallop_usdc::SCALLOP_USDC")?.decimals == 6)
    }

    /// Sampled direct-registry entries must all carry decimals (the bake-in must
    /// be complete — a nil means a coin would silently fall back to the RPC).
    @Test func sampled_registry_entries_have_decimals() {
        let samples = [
            "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI",
            "0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ysui::YSUI",
            "0x1798f84ee72176114ddbf5525a6d964c5f8ea1b3738d08d50d0d3de4cf584884::sbuck::SBUCK",
            "0xaafc4f740de0dd0dde642a31148fb94517087052f19afb0f7bed1dc41a50c77b::scallop_sui::SCALLOP_SUI",
        ]
        for ct in samples {
            #expect(KnownProtocols.enrichment(forCoinType: ct)?.decimals != nil, "missing decimals for \(ct)")
        }
    }
}
