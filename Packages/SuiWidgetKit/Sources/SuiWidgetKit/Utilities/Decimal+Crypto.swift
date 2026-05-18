import Foundation

public extension Decimal {
    /// Parses a Sui u64-as-string (e.g. `"123456789"`) into a Decimal preserving full precision.
    /// Returns nil for non-numeric or negative inputs.
    init?(suiU64String s: String) {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        guard value >= 0 else { return nil }
        self = value
    }
}

/// Codable adapter that decodes a string field into Decimal via `Decimal(suiU64String:)`.
/// Use as the inner type of a `@propertyWrapper`-free transform: decode into this, then access `.value`.
public struct SuiU64DecimalCodable: Codable, Equatable, Sendable {
    public let value: Decimal

    public init(value: Decimal) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = Decimal(suiU64String: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected u64 string, got \(raw)"
            )
        }
        self.value = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(value)")
    }
}
