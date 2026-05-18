import Foundation

/// Validated Sui mainnet address. 32-byte value rendered as 64 lowercase hex digits prefixed with `0x`.
public struct SuiAddress: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    private static let hexCharacters: Set<Character> = Set("0123456789abcdef")

    public let rawValue: String

    /// Accepts only the canonical Sui form: literal lowercase `0x` prefix + 64 hex characters (case-insensitive).
    /// Rejects `0X` uppercase prefix, missing/extra characters, non-hex bytes, and whitespace.
    public init?(rawValue: String) {
        guard rawValue.hasPrefix("0x"), rawValue.count == 66 else { return nil }
        let hex = rawValue.dropFirst(2).lowercased()
        guard hex.allSatisfy(Self.hexCharacters.contains) else { return nil }
        self.rawValue = "0x" + hex
    }

    public var description: String { rawValue }
}
