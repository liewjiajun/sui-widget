import Foundation

/// Registry of known Sui DeFi protocols whose receipts / wrappers a user's
/// `suix_getAllBalances` call surfaces as ordinary coins. Without enrichment
/// these positions appear as untracked tokens with no price, so the portfolio
/// total understates the user's actual holdings — exactly the "show where my
/// tokens are staked / lent" requirement.
///
/// The registry serves two purposes: (1) a **pricing fallback** — value a
/// wrapper via its underlying asset when no source prices the wrapper directly;
/// and (2) **tagging** — route a coin into the Earning section with a protocol
/// name + category, even when DeFiLlama already priced it.
///
/// EVERY coin type below was live-verified via `suix_getCoinMetadata` on Sui
/// mainnet, and each has a DeFiLlama-priceable underlying. We never fabricate a
/// coin type: anything not in this set still shows as an honest "untracked" row
/// rather than a mispriced one. Protocols whose positions are on-chain *objects*
/// rather than fungible coins (Suilend/NAVI lending, Cetus/Bluefin/Turbos/
/// Momentum CLMM LPs, AlphaFi classic vaults, Bucket CDP bottles, Kai leverage)
/// cannot be valued from a balance map and are intentionally excluded.
public enum KnownProtocols {

    /// Broad class of a DeFi position, used to group rows under the "Earning"
    /// section and to label each with a category pill.
    public enum Category: String, Equatable, Sendable {
        case liquidStaking = "Liquid staking"
        case lending = "Lending"
        case liquidity = "Liquidity"

        /// SF Symbol used for the category's glyph in the UI.
        public var systemImage: String {
            switch self {
            case .liquidStaking: return "drop.circle.fill"
            case .lending: return "banknote.fill"
            case .liquidity: return "circle.hexagongrid.fill"
            }
        }
    }

    /// One enriched mapping: tells `PortfolioService` how to price a wrapped
    /// position and what tag + category to attach to the resulting row.
    public struct EnrichedHolding: Equatable, Sendable {
        public let dappName: String
        public let symbolOverride: String?
        public let underlyingCanonicalCoinType: String
        public let category: Category
        /// The receipt coin's OWN on-chain decimals (not the underlying's),
        /// live-verified and baked into the registry. Lets `PortfolioService`
        /// convert base units without a refresh-time `getCoinMetadata` RPC —
        /// critical for positions priced via their underlying (every Kai yToken)
        /// where no price source reports the receipt's decimals.
        public let decimals: Int?
        public init(
            dappName: String,
            symbolOverride: String? = nil,
            underlyingCanonicalCoinType: String,
            category: Category,
            decimals: Int? = nil
        ) {
            self.dappName = dappName
            self.symbolOverride = symbolOverride
            self.underlyingCanonicalCoinType = underlyingCanonicalCoinType
            self.category = category
            self.decimals = decimals
        }
    }

    /// Canonical SUI coin type — the underlying for every SUI-LST in the registry.
    public static let suiCanonical = CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI")

    /// Direct (full-coin-type) registry. Keys are canonicalised so they match
    /// what `PortfolioService` does when keying the price lookup. The newer
    /// standalone Scallop `scallop_xxx::SCALLOP_XXX` sCoins live here; the legacy
    /// `reserve::MarketCoin<U>` form is handled by the pattern-matcher below.
    private static let directRegistry: [String: EnrichedHolding] = {
        let entries: [(String, EnrichedHolding)] = [

        // MARK: Liquid staking receipts (LSTs)
        ("0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI",
         EnrichedHolding(dappName: "Aftermath", symbolOverride: "afSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55::stsui::STSUI",
         EnrichedHolding(dappName: "AlphaFi", symbolOverride: "stSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0x790f258062909e3a0ffc78b3c53ac2f62d7084c3bab95644bdeb05add7250001::super_sui::SUPER_SUI",
         EnrichedHolding(dappName: "AlphaFi", symbolOverride: "superSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0xe68fad47384e18cd79040cb8d72b7f64d267eebb73a0b8d54711aa860570f404::upsui::UPSUI",
         EnrichedHolding(dappName: "DoubleUp", symbolOverride: "upSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0x02358129a7d66f943786a10b518fdc79145f1fc8d23420d9948c4aeea190f603::fud_sui::FUD_SUI",
         EnrichedHolding(dappName: "FUD", symbolOverride: "fudSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI",
         EnrichedHolding(dappName: "Haedal", symbolOverride: "haSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0x8b4d553839b219c3fd47608a0cc3d5fcc572cb25d41b7df3833208586a8d2470::hawal::HAWAL",
         EnrichedHolding(dappName: "Haedal", symbolOverride: "haWAL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL"),
                         category: .liquidStaking)),
        ("0x922d15d7f55c13fd790f6e54397470ec592caa2b508df292a2e8553f3d3b274f::msui::MSUI",
         EnrichedHolding(dappName: "Mirai", symbolOverride: "mSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0x83556891f4a0f233ce7b05cfe7f957d4020492a34f5405b2cb9377d060bef4bf::spring_sui::SPRING_SUI",
         EnrichedHolding(dappName: "SpringSui", symbolOverride: "sSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0x502867b177303bf1bf226245fcdd3403c177e78d175a55a56c0602c7ff51c7fa::trevin_sui::TREVIN_SUI",
         EnrichedHolding(dappName: "Trevin", symbolOverride: "trevinSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT",
         EnrichedHolding(dappName: "Volo", symbolOverride: "vSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .liquidStaking)),
        ("0xb1b0650a8862e30e3f604fd6c5838bc25464b8d3d827fbd58af7cb9685b832bf::wwal::WWAL",
         EnrichedHolding(dappName: "Walrus", symbolOverride: "wWAL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL"),
                         category: .liquidStaking)),

        // MARK: Lending / savings / vault receipts
        ("0x1798f84ee72176114ddbf5525a6d964c5f8ea1b3738d08d50d0d3de4cf584884::sbuck::SBUCK",
         EnrichedHolding(dappName: "Bucket", symbolOverride: "sBUCK",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::buck::BUCK"),
                         category: .lending)),
        ("0x5b2fa5c76309a417ccd14a65f036b8d1ff4e76a143ed878a47fdecfe0b09860e::ydeep::YDEEP",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yDEEP",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xdeeb7a4662eec9f2f3def03fb937a663dddaa2e215b8078a284d026b7946c270::deep::DEEP"),
                         category: .lending)),
        ("0x3e83d9c798902dbcde72b9ede9fa2997ea43b302f83e4894aa793e6791e95c9f::ylbtc::YLBTC",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yLBTC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x3e8e9423d80e1774a7ca128fccd8bf5f1f7753be658c5e645929037f7c819040::lbtc::LBTC"),
                         category: .lending)),
        ("0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ysui::YSUI",
         EnrichedHolding(dappName: "Kai", symbolOverride: "ySUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .lending)),
        ("0x01c389a85310b47e7630a9361d4e71025bc35e4999d3a645949b1b68b26f2273::ywhusdce::YWHUSDCE",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yUSDC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN"),
                         category: .lending)),
        ("0x7ea359636b36e7c027c2cd71adedaf19be658e1477d9e71368a0b3824a0a27ff::yusdc::YUSDC",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yUSDC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC"),
                         category: .lending)),
        ("0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ywhusdte::YWHUSDTE",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yUSDT",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN"),
                         category: .lending)),
        ("0xdd7108db1a209d23d8a25dda78bdca4547b755094305971ed4064dfe5cdfa026::yusdy::YUSDY",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yUSDY",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x960b531667636f39e85867775f52f6b1f220a058c4de786905bdf761e06a56bb::usdy::USDY"),
                         category: .lending)),
        ("0xdab19711df7a4eefc633b9426e15d23305c6815eed775247e477599c706ede98::ywal::YWAL",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yWAL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL"),
                         category: .lending)),
        ("0xfc39a879b5a8772f682f1202cc5a8a3d93654cbb9e716b96bda7e5832af0e0eb::yxbtc::YXBTC",
         EnrichedHolding(dappName: "Kai", symbolOverride: "yXBTC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x876a4b7bce8aeaef60464c11f4026903e9afacab79b9b142686158aa86560b50::xbtc::XBTC"),
                         category: .lending)),
        ("0x36bc697c1dba827a4bf7fa3bfc9f1b0953fe09b91c4b4c103efa0b086e03d923::ysuiusdt::YSUIUSDT",
         EnrichedHolding(dappName: "Kai", symbolOverride: "ysuiUSDT",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT"),
                         category: .lending)),
        ("0x00671b1fa2a124f5be8bdae8b91ee711462c5d9e31bda232e70fd9607b523c88::scallop_af_sui::SCALLOP_AF_SUI",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sAfSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI"),
                         category: .lending)),
        ("0xea346ce428f91ab007210443efcea5f5cdbbb3aae7e9affc0ca93f9203c31f0c::scallop_cetus::SCALLOP_CETUS",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sCETUS",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x06864a6f921804860930db6ddbe2e16acdf8504495ea7481637a1c8b9a8fe54b::cetus::CETUS"),
                         category: .lending)),
        ("0xeb7a05a3224837c5e5503575aed0be73c091d1ce5e43aa3c3e716e0ae614608f::scallop_deep::SCALLOP_DEEP",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sDEEP",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xdeeb7a4662eec9f2f3def03fb937a663dddaa2e215b8078a284d026b7946c270::deep::DEEP"),
                         category: .lending)),
        ("0x6711551c1e7652a270d9fbf0eee25d99594c157cde3cb5fbb49035eb59b1b001::scallop_fdusd::SCALLOP_FDUSD",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sFDUSD",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xf16e6b723f242ec745dfd7634ad072c42d5c1d9ac9d62a39c381303eaa57693a::fdusd::FDUSD"),
                         category: .lending)),
        ("0xe56d5167f427cbe597da9e8150ef5c337839aaf46891d62468dcf80bdd8e10d1::scallop_fud::SCALLOP_FUD",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sFUD",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x76cb819b01abed502bee8a702b4c2d547532c12f25001c9dea795a5e631c26f1::fud::FUD"),
                         category: .lending)),
        ("0x0425be5f46f5639ab7201dfde3b2ed837fc129c434f55677c9ba11b528a3214a::scallop_haedal::SCALLOP_HAEDAL",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sHAEDAL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x3a304c7feba2d819ea57c3542d68439ca2c386ba02159c740f7b406e592c62ea::haedal::HAEDAL"),
                         category: .lending)),
        ("0x9a2376943f7d22f88087c259c5889925f332ca4347e669dc37d54c2bf651af3c::scallop_ha_sui::SCALLOP_HA_SUI",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sHaSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI"),
                         category: .lending)),
        ("0x6511052d2f1404934e0d877709949bcda7c1d451d1218a4b2643ca2f3fa93991::scallop_ns::SCALLOP_NS",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sNS",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x5145494a5f5100e645e4b0aa950fa6b68f614e8c59e17bc5ded3495123a79178::ns::NS"),
                         category: .lending)),
        ("0xb14f82d8506d139eacef109688d1b71e7236bcce9b2c0ad526abcd6aa5be7de0::scallop_sb_eth::SCALLOP_SB_ETH",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sSBETH",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xd0e89b2af5e4910726fbcd8b8dd37bb79b29e5f83f7491bca830e94f7f226d29::eth::ETH"),
                         category: .lending)),
        ("0xb1d7df34829d1513b73ba17cb7ad90c88d1e104bb65ab8f62f13e0cc103783d3::scallop_sb_usdt::SCALLOP_SB_USDT",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sSBUSDT",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT"),
                         category: .lending)),
        ("0x08c0fe357d3a138f4552bee393ce3a28a45bebcca43373d6a90bc44ab76f82e2::scallop_sb_wbtc::SCALLOP_SB_WBTC",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sSBWBTC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xaafb102dd0902f5055cadecd687fb5b71ca82ef0e0285d90afde828ec58ca96b::btc::BTC"),
                         category: .lending)),
        ("0x5ca17430c1d046fae9edeaa8fd76c7b4193a00d764a0ecfa9418d733ad27bc1e::scallop_sca::SCALLOP_SCA",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sSCA",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x7016aae72cfc67f2fadf55769c0a7dd54291a583b63051a5ed71081cce836ac6::sca::SCA"),
                         category: .lending)),
        ("0xaafc4f740de0dd0dde642a31148fb94517087052f19afb0f7bed1dc41a50c77b::scallop_sui::SCALLOP_SUI",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI"),
                         category: .lending)),
        ("0x854950aa624b1df59fe64e630b2ba7c550642e9342267a33061d59fb31582da5::scallop_usdc::SCALLOP_USDC",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sUSDC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC"),
                         category: .lending)),
        ("0xd285cbbf54c87fd93cd15227547467bb3e405da8bbf2ab99f83f323f88ac9a65::scallop_usdy::SCALLOP_USDY",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sUSDY",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x960b531667636f39e85867775f52f6b1f220a058c4de786905bdf761e06a56bb::usdy::USDY"),
                         category: .lending)),
        ("0xe1a1cc6bcf0001a015eab84bcc6713393ce20535f55b8b6f35c142e057a25fbe::scallop_v_sui::SCALLOP_V_SUI",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sVSUI",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT"),
                         category: .lending)),
        ("0x622345b3f80ea5947567760eec7b9639d0582adcfd6ab9fccb85437aeda7c0d0::scallop_wal::SCALLOP_WAL",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sWAL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL"),
                         category: .lending)),
        ("0x67540ceb850d418679e69f1fb6b2093d6df78a2a699ffc733f7646096d552e9b::scallop_wormhole_eth::SCALLOP_WORMHOLE_ETH",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sWETH",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade5874359610ef8eeced5::coin::COIN"),
                         category: .lending)),
        ("0x1392650f2eca9e3f6ffae3ff89e42a3590d7102b80e2b430f674730bc30d3259::scallop_wormhole_sol::SCALLOP_WORMHOLE_SOL",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sWSOL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xb7844e289a8410e50fb3ca48d69eb9cf29e27d223ef90353fe1bd8e27ff8f3f8::coin::COIN"),
                         category: .lending)),
        ("0xad4d71551d31092230db1fd482008ea42867dbf27b286e9c70a79d2a6191d58d::scallop_wormhole_usdc::SCALLOP_WORMHOLE_USDC",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sWUSDC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN"),
                         category: .lending)),
        ("0xe6e5a012ec20a49a3d1d57bd2b67140b96cd4d3400b9d79e541f7bdbab661f95::scallop_wormhole_usdt::SCALLOP_WORMHOLE_USDT",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sWUSDT",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN"),
                         category: .lending)),
        ("0xa2859d61462635912553746e1b28a54e90b6ad6270f1e7c7db73761a9d6ba1e1::scallop_xbtc::SCALLOP_XBTC",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "sXBTC",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x876a4b7bce8aeaef60464c11f4026903e9afacab79b9b142686158aa86560b50::xbtc::XBTC"),
                         category: .lending)),
        ("0x7cb7cdf180891bc67a13f369a2ab8f5a05d018dc6cb1f60d04bcfca842c6fb3f::scallop_ha_wal::SCALLOP_HA_WAL",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "shaWAL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0x8b4d553839b219c3fd47608a0cc3d5fcc572cb25d41b7df3833208586a8d2470::hawal::HAWAL"),
                         category: .lending)),
        ("0x0a228d1c59071eccf3716076a1f71216846ee256d9fb07ea11fb7c1eb56435a5::scallop_musd::SCALLOP_MUSD",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "smUSD",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xe44df51c0b21a27ab915fa1fe2ca610cd3eaa6d9666fe5e62b988bf7f0bd8722::musd::MUSD"),
                         category: .lending)),
        ("0x1af58255ce892974e6204b202a6d88fe7c0d00ee27ec9f7078ee827572a229bf::scallop_w_wal::SCALLOP_W_WAL",
         EnrichedHolding(dappName: "Scallop", symbolOverride: "swWAL",
                         underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize("0xb1b0650a8862e30e3f604fd6c5838bc25464b8d3d827fbd58af7cb9685b832bf::wwal::WWAL"),
                         category: .lending)),
        ]
        return Dictionary(
            entries.map { (CoinTypeCanonicalizer.canonicalize($0.0), $0.1) },
            uniquingKeysWith: { first, _ in first }
        )
    }()

    /// On-chain decimals for every registry coin type, captured live via
    /// `suix_getCoinMetadata` on mainnet. Baked in so a position priced via
    /// its underlying (e.g. every Kai yToken — DeFiLlama prices none of them
    /// directly) never needs a refresh-time metadata RPC for its decimals.
    /// Without this, a rate-limited RPC defaulted to 9 and a 6-decimal
    /// yUSDC amount came out 1000x too small (the reported Kai bug). Keys
    /// are canonical (64-hex) coin types.
    static let verifiedDecimals: [String: Int] = [
        "0x00671b1fa2a124f5be8bdae8b91ee711462c5d9e31bda232e70fd9607b523c88::scallop_af_sui::SCALLOP_AF_SUI": 9,
        "0x01c389a85310b47e7630a9361d4e71025bc35e4999d3a645949b1b68b26f2273::ywhusdce::YWHUSDCE": 6,
        "0x02358129a7d66f943786a10b518fdc79145f1fc8d23420d9948c4aeea190f603::fud_sui::FUD_SUI": 9,
        "0x0425be5f46f5639ab7201dfde3b2ed837fc129c434f55677c9ba11b528a3214a::scallop_haedal::SCALLOP_HAEDAL": 9,
        "0x08c0fe357d3a138f4552bee393ce3a28a45bebcca43373d6a90bc44ab76f82e2::scallop_sb_wbtc::SCALLOP_SB_WBTC": 8,
        "0x0a228d1c59071eccf3716076a1f71216846ee256d9fb07ea11fb7c1eb56435a5::scallop_musd::SCALLOP_MUSD": 9,
        "0x1392650f2eca9e3f6ffae3ff89e42a3590d7102b80e2b430f674730bc30d3259::scallop_wormhole_sol::SCALLOP_WORMHOLE_SOL": 8,
        "0x1798f84ee72176114ddbf5525a6d964c5f8ea1b3738d08d50d0d3de4cf584884::sbuck::SBUCK": 9,
        "0x1af58255ce892974e6204b202a6d88fe7c0d00ee27ec9f7078ee827572a229bf::scallop_w_wal::SCALLOP_W_WAL": 9,
        "0x36bc697c1dba827a4bf7fa3bfc9f1b0953fe09b91c4b4c103efa0b086e03d923::ysuiusdt::YSUIUSDT": 6,
        "0x3e83d9c798902dbcde72b9ede9fa2997ea43b302f83e4894aa793e6791e95c9f::ylbtc::YLBTC": 8,
        "0x502867b177303bf1bf226245fcdd3403c177e78d175a55a56c0602c7ff51c7fa::trevin_sui::TREVIN_SUI": 9,
        "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT": 9,
        "0x5b2fa5c76309a417ccd14a65f036b8d1ff4e76a143ed878a47fdecfe0b09860e::ydeep::YDEEP": 6,
        "0x5ca17430c1d046fae9edeaa8fd76c7b4193a00d764a0ecfa9418d733ad27bc1e::scallop_sca::SCALLOP_SCA": 9,
        "0x622345b3f80ea5947567760eec7b9639d0582adcfd6ab9fccb85437aeda7c0d0::scallop_wal::SCALLOP_WAL": 9,
        "0x6511052d2f1404934e0d877709949bcda7c1d451d1218a4b2643ca2f3fa93991::scallop_ns::SCALLOP_NS": 6,
        "0x6711551c1e7652a270d9fbf0eee25d99594c157cde3cb5fbb49035eb59b1b001::scallop_fdusd::SCALLOP_FDUSD": 6,
        "0x67540ceb850d418679e69f1fb6b2093d6df78a2a699ffc733f7646096d552e9b::scallop_wormhole_eth::SCALLOP_WORMHOLE_ETH": 8,
        "0x790f258062909e3a0ffc78b3c53ac2f62d7084c3bab95644bdeb05add7250001::super_sui::SUPER_SUI": 9,
        "0x7cb7cdf180891bc67a13f369a2ab8f5a05d018dc6cb1f60d04bcfca842c6fb3f::scallop_ha_wal::SCALLOP_HA_WAL": 9,
        "0x7ea359636b36e7c027c2cd71adedaf19be658e1477d9e71368a0b3824a0a27ff::yusdc::YUSDC": 6,
        "0x83556891f4a0f233ce7b05cfe7f957d4020492a34f5405b2cb9377d060bef4bf::spring_sui::SPRING_SUI": 9,
        "0x854950aa624b1df59fe64e630b2ba7c550642e9342267a33061d59fb31582da5::scallop_usdc::SCALLOP_USDC": 6,
        "0x8b4d553839b219c3fd47608a0cc3d5fcc572cb25d41b7df3833208586a8d2470::hawal::HAWAL": 9,
        "0x922d15d7f55c13fd790f6e54397470ec592caa2b508df292a2e8553f3d3b274f::msui::MSUI": 9,
        "0x9a2376943f7d22f88087c259c5889925f332ca4347e669dc37d54c2bf651af3c::scallop_ha_sui::SCALLOP_HA_SUI": 9,
        "0xa2859d61462635912553746e1b28a54e90b6ad6270f1e7c7db73761a9d6ba1e1::scallop_xbtc::SCALLOP_XBTC": 8,
        "0xaafc4f740de0dd0dde642a31148fb94517087052f19afb0f7bed1dc41a50c77b::scallop_sui::SCALLOP_SUI": 9,
        "0xad4d71551d31092230db1fd482008ea42867dbf27b286e9c70a79d2a6191d58d::scallop_wormhole_usdc::SCALLOP_WORMHOLE_USDC": 6,
        "0xb14f82d8506d139eacef109688d1b71e7236bcce9b2c0ad526abcd6aa5be7de0::scallop_sb_eth::SCALLOP_SB_ETH": 8,
        "0xb1b0650a8862e30e3f604fd6c5838bc25464b8d3d827fbd58af7cb9685b832bf::wwal::WWAL": 9,
        "0xb1d7df34829d1513b73ba17cb7ad90c88d1e104bb65ab8f62f13e0cc103783d3::scallop_sb_usdt::SCALLOP_SB_USDT": 6,
        "0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ysui::YSUI": 9,
        "0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ywhusdte::YWHUSDTE": 6,
        "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI": 9,
        "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55::stsui::STSUI": 9,
        "0xd285cbbf54c87fd93cd15227547467bb3e405da8bbf2ab99f83f323f88ac9a65::scallop_usdy::SCALLOP_USDY": 6,
        "0xdab19711df7a4eefc633b9426e15d23305c6815eed775247e477599c706ede98::ywal::YWAL": 9,
        "0xdd7108db1a209d23d8a25dda78bdca4547b755094305971ed4064dfe5cdfa026::yusdy::YUSDY": 6,
        "0xe1a1cc6bcf0001a015eab84bcc6713393ce20535f55b8b6f35c142e057a25fbe::scallop_v_sui::SCALLOP_V_SUI": 9,
        "0xe56d5167f427cbe597da9e8150ef5c337839aaf46891d62468dcf80bdd8e10d1::scallop_fud::SCALLOP_FUD": 5,
        "0xe68fad47384e18cd79040cb8d72b7f64d267eebb73a0b8d54711aa860570f404::upsui::UPSUI": 9,
        "0xe6e5a012ec20a49a3d1d57bd2b67140b96cd4d3400b9d79e541f7bdbab661f95::scallop_wormhole_usdt::SCALLOP_WORMHOLE_USDT": 6,
        "0xea346ce428f91ab007210443efcea5f5cdbbb3aae7e9affc0ca93f9203c31f0c::scallop_cetus::SCALLOP_CETUS": 9,
        "0xeb7a05a3224837c5e5503575aed0be73c091d1ce5e43aa3c3e716e0ae614608f::scallop_deep::SCALLOP_DEEP": 6,
        "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI": 9,
        "0xfc39a879b5a8772f682f1202cc5a8a3d93654cbb9e716b96bda7e5832af0e0eb::yxbtc::YXBTC": 8,
    ]

    /// Lending protocols whose receipt coins wrap an underlying asset inside a
    /// generic type parameter (e.g. `<pkg>::reserve::MarketCoin<USDC>`). For each
    /// we parse the underlying out and price the position via that asset. Covers
    /// Scallop's legacy sCoin form (its newer standalone sCoins are in the direct
    /// registry above). Pricing via the underlying is a first-order approximation
    /// (the receipt accrues interest) — correct vs. "value at zero".
    private struct LendingWrapper {
        let dappName: String
        let typeInfix: String      // e.g. "::reserve::MarketCoin<"
        let symbolPrefix: String   // e.g. "s" -> sUSDC
        let package: String
    }

    private static let lendingWrappers: [LendingWrapper] = [
        // Scallop Protocol legacy MarketCoin sCoins.
        LendingWrapper(
            dappName: "Scallop",
            typeInfix: "::reserve::MarketCoin<",
            symbolPrefix: "s",
            package: "0xefe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf"
        ),
    ]

    /// Backwards-compatible alias for the Scallop package (referenced by tests).
    public static var scallopPackage: String { lendingWrappers[0].package }

    /// Count of explicitly-registered coin types (excludes the pattern-matched
    /// legacy Scallop family). Useful for tests / diagnostics.
    public static var registeredCoinTypeCount: Int { directRegistry.count }

    /// Looks up an enriched mapping for a given on-chain coin type. The input is
    /// the raw (possibly short-form) coin type from `suix_getAllBalances`;
    /// callers don't need to canonicalise it themselves.
    public static func enrichment(forCoinType raw: String) -> EnrichedHolding? {
        let canonical = CoinTypeCanonicalizer.canonicalize(raw)
        if let direct = directRegistry[canonical] {
            return withVerifiedDecimals(direct, canonical: canonical)
        }
        if let wrapped = lendingEnrichment(canonical: canonical) {
            // Legacy Scallop MarketCoin<U> has the same decimals as its
            // underlying U; carry that through so the amount is correct.
            return withVerifiedDecimals(wrapped, canonical: wrapped.underlyingCanonicalCoinType)
        }
        return nil
    }

    /// Returns `holding` with its `decimals` filled from the live-verified map
    /// when known (keyed by `canonical`), so callers never need a metadata RPC.
    private static func withVerifiedDecimals(_ holding: EnrichedHolding, canonical: String) -> EnrichedHolding {
        guard holding.decimals == nil, let dec = verifiedDecimals[canonical] else { return holding }
        return EnrichedHolding(
            dappName: holding.dappName,
            symbolOverride: holding.symbolOverride,
            underlyingCanonicalCoinType: holding.underlyingCanonicalCoinType,
            category: holding.category,
            decimals: dec
        )
    }

    private static func lendingEnrichment(canonical: String) -> EnrichedHolding? {
        for wrapper in lendingWrappers {
            let prefix = wrapper.package + wrapper.typeInfix
            guard canonical.hasPrefix(prefix), canonical.hasSuffix(">") else { continue }
            let underlyingStart = canonical.index(canonical.startIndex, offsetBy: prefix.count)
            let underlyingEnd = canonical.index(before: canonical.endIndex)
            let underlying = String(canonical[underlyingStart..<underlyingEnd])
            let symbol = underlying
                .split(separator: ":")
                .last
                .map { String($0) }
                .map { wrapper.symbolPrefix + $0.uppercased() }
            return EnrichedHolding(
                dappName: wrapper.dappName,
                symbolOverride: symbol,
                underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize(underlying),
                category: .lending
            )
        }
        return nil
    }
}
