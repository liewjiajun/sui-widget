import Foundation
import Testing
@testable import SuiWidgetKit

@Suite("SuiAddress")
struct SuiAddressTests {
    @Test func accepts_lowercase_64hex_with_0x_prefix() {
        let raw = "0x" + String(repeating: "a", count: 64)
        #expect(SuiAddress(rawValue: raw)?.rawValue == raw)
    }

    @Test func normalizes_mixed_case_to_lowercase() {
        let raw = "0x" + String(repeating: "A", count: 64)
        #expect(SuiAddress(rawValue: raw)?.rawValue == raw.lowercased())
    }

    @Test func rejects_missing_prefix() {
        let raw = String(repeating: "a", count: 64)
        #expect(SuiAddress(rawValue: raw) == nil)
    }

    @Test func rejects_wrong_length() {
        #expect(SuiAddress(rawValue: "0xab") == nil)
        #expect(SuiAddress(rawValue: "0x" + String(repeating: "a", count: 65)) == nil)
    }

    @Test func rejects_non_hex_characters() {
        let raw = "0x" + String(repeating: "g", count: 64)
        #expect(SuiAddress(rawValue: raw) == nil)
    }

    @Test func rejects_uppercase_0X_prefix() {
        let raw = "0X" + String(repeating: "a", count: 64)
        #expect(SuiAddress(rawValue: raw) == nil)
    }

    @Test func rejects_empty_string() {
        #expect(SuiAddress(rawValue: "") == nil)
    }

    @Test func rejects_just_prefix() {
        #expect(SuiAddress(rawValue: "0x") == nil)
    }

    @Test func accepts_all_zeros() {
        let raw = "0x" + String(repeating: "0", count: 64)
        #expect(SuiAddress(rawValue: raw)?.rawValue == raw)
    }

    @Test func is_codable_round_trip() throws {
        let raw = "0x" + String(repeating: "a", count: 64)
        let address = SuiAddress(rawValue: raw)!
        let data = try JSONEncoder().encode(address)
        let decoded = try JSONDecoder().decode(SuiAddress.self, from: data)
        #expect(decoded == address)
    }
}
