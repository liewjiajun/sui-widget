import Foundation
import Testing
@testable import SuiWidgetKit

/// Regression coverage for the lenient `suix_getOwnedObjects` decoding. Real
/// NFT collections emit display maps with null / numeric / boolean values and
/// occasionally whole malformed objects; a strict `[String: String]` decode
/// aborted the entire page and the user saw "expected to decode String" with
/// zero NFTs grabbed.
@Suite("SuiRPC lenient decoding")
struct SuiRPCDecodingTests {

    private func decodePage(_ json: String) throws -> SuiOwnedObjectsPage {
        try JSONDecoder().decode(SuiOwnedObjectsPage.self, from: Data(json.utf8))
    }

    @Test func display_data_with_null_value_does_not_abort_decode() throws {
        let json = """
        {
          "data": [
            { "data": { "objectId": "0xaaa", "type": "0x1::nft::NFT",
              "display": { "data": { "name": "Has Null", "image_url": null }, "error": null } } }
          ],
          "nextCursor": null,
          "hasNextPage": false
        }
        """
        let page = try decodePage(json)
        #expect(page.data.count == 1)
        let obj = try #require(page.data.first?.data)
        #expect(obj.objectId == "0xaaa")
        #expect(obj.display?.data?["name"] == "Has Null")
        // The null value is dropped — not crashed on.
        #expect(obj.display?.data?["image_url"] == nil)
    }

    @Test func display_data_with_numeric_and_bool_values_coerced_to_string() throws {
        let json = """
        {
          "data": [
            { "data": { "objectId": "0xbbb", "type": "0x1::nft::NFT",
              "display": { "data": { "name": "Numeric", "edition": 42, "rare": true } } } }
          ],
          "hasNextPage": false
        }
        """
        let page = try decodePage(json)
        let obj = try #require(page.data.first?.data)
        #expect(obj.display?.data?["edition"] == "42")
        #expect(obj.display?.data?["rare"] == "true")
        #expect(obj.display?.data?["name"] == "Numeric")
    }

    @Test func malformed_object_is_dropped_while_valid_one_survives() throws {
        // First object's objectId is a number — invalid. It must be dropped
        // while the second, valid object survives the page decode.
        let json = """
        {
          "data": [
            { "data": { "objectId": 12345, "type": "0x1::nft::NFT" } },
            { "data": { "objectId": "0xccc", "type": "0x1::nft::NFT",
              "display": { "data": { "name": "Good" } } } }
          ],
          "hasNextPage": false
        }
        """
        let page = try decodePage(json)
        #expect(page.data.count == 1)
        #expect(page.data.first?.data?.objectId == "0xccc")
    }

    @Test func wrapper_with_error_instead_of_data_decodes_to_nil_inner() throws {
        let json = """
        {
          "data": [
            { "error": { "code": "notExists", "object_id": "0xddd" } }
          ],
          "hasNextPage": false
        }
        """
        let page = try decodePage(json)
        #expect(page.data.count == 1)
        #expect(page.data.first?.data == nil)
    }

    @Test func display_block_with_null_data_decodes_to_nil() throws {
        let json = """
        {
          "data": [
            { "data": { "objectId": "0xeee", "type": "0x2::coin::Coin",
              "display": { "data": null, "error": null } } }
          ],
          "hasNextPage": false
        }
        """
        let page = try decodePage(json)
        let obj = try #require(page.data.first?.data)
        #expect(obj.display?.data == nil)
    }

    @Test func missing_hasNextPage_defaults_to_false() throws {
        let json = """
        { "data": [], "nextCursor": null }
        """
        let page = try decodePage(json)
        #expect(page.hasNextPage == false)
        #expect(page.data.isEmpty)
    }
}
