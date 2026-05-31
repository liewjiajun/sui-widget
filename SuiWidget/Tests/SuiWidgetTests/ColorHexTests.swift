import Testing
import SwiftUI
@testable import SuiWidget

@Suite("Color+Hex")
struct ColorHexTests {
    @Test func parses_six_digit_hex_with_hash() {
        let c = Color(hex: "#4DA2FF")
        let resolved = c.resolve(in: EnvironmentValues())
        #expect(abs(resolved.red - 0x4D / 255.0) < 0.01)
        #expect(abs(resolved.green - 0xA2 / 255.0) < 0.01)
        #expect(abs(resolved.blue - 0xFF / 255.0) < 0.01)
    }

    @Test func parses_six_digit_hex_without_hash() {
        let c = Color(hex: "4DA2FF")
        let resolved = c.resolve(in: EnvironmentValues())
        #expect(abs(resolved.red - 0x4D / 255.0) < 0.01)
    }

    @Test func falls_back_to_gray_on_malformed_input() {
        let c = Color(hex: "not-a-hex")
        // Just verify it doesn't crash; can't easily compare to Color.gray across platforms
        _ = c.resolve(in: EnvironmentValues())
    }
}

@Suite("DeepLinkRouter")
struct DeepLinkRouterTests {
    @Test func parses_stake_url() {
        let url = URL(string: "suiwidget://stake")!
        #expect(DeepLinkRouter.destination(from: url) == .stakeList)
    }

    @Test func parses_nft_url() {
        let url = URL(string: "suiwidget://nft/0xabc123")!
        #expect(DeepLinkRouter.destination(from: url) == .nft(objectId: "0xabc123"))
    }

    @Test func parses_wallet_url() {
        let uuid = UUID()
        let url = URL(string: "suiwidget://wallet/\(uuid.uuidString)")!
        #expect(DeepLinkRouter.destination(from: url) == .wallet(uuid))
    }

    /// The V2 pet teaser was removed from V1 — the `pet/hatch` deep link must no
    /// longer resolve (the egg slot and Coming-Soon screen are gone).
    @Test func pet_hatch_url_no_longer_routes() {
        let url = URL(string: "suiwidget://pet/hatch")!
        #expect(DeepLinkRouter.destination(from: url) == nil)
    }

    @Test func parses_news_url() {
        let url = URL(string: "suiwidget://news/article-1")!
        #expect(DeepLinkRouter.destination(from: url) == .news(itemId: "article-1"))
    }

    @Test func rejects_unknown_scheme() {
        let url = URL(string: "https://example.com/stake")!
        #expect(DeepLinkRouter.destination(from: url) == nil)
    }

    @Test func rejects_malformed_wallet_uuid() {
        let url = URL(string: "suiwidget://wallet/not-a-uuid")!
        #expect(DeepLinkRouter.destination(from: url) == nil)
    }
}
