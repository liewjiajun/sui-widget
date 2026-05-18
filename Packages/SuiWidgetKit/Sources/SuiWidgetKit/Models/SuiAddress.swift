import Foundation

public struct SuiAddress: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        let lower = rawValue.lowercased()
        guard lower.hasPrefix("0x"), lower.count == 66 else { return nil }
        let hex = lower.dropFirst(2)
        let allowed: Set<Character> = Set("0123456789abcdef")
        guard hex.allSatisfy({ allowed.contains($0) }) else { return nil }
        self.rawValue = lower
    }

    public var description: String { rawValue }
}
