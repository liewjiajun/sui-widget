import Foundation

/// Sui coin types canonicalize the package address to 64 lowercase hex chars.
/// Sui RPC frequently returns the short form (e.g. `0x2::sui::SUI`) while other
/// sources (CoinGecko platforms map, on-chain Move metadata) use the long form
/// (`0x0000…0002::sui::SUI`). Use this helper to convert between them.
public enum CoinTypeCanonicalizer {
    /// Returns the canonical (64-hex-char prefix) form of a coin type.
    /// - `0x2::sui::SUI` → `0x0000…0002::sui::SUI`
    /// - Already-canonical input is returned unchanged.
    /// - Inputs without `0x` prefix, or with non-hex prefix, are returned unchanged.
    public static func canonicalize(_ coinType: String) -> String {
        let parts = coinType.split(separator: "::", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return coinType.lowercased() }
        let rawAddress = String(parts[0])
        let rest = String(parts[1])
        guard rawAddress.hasPrefix("0x") else { return coinType.lowercased() }
        let hex = rawAddress.dropFirst(2).lowercased()
        let allowed: Set<Character> = Set("0123456789abcdef")
        guard hex.allSatisfy(allowed.contains) else { return coinType.lowercased() }
        let padded = String(repeating: "0", count: max(0, 64 - hex.count)) + hex
        return "0x\(padded)::\(rest)"
    }

    /// Returns true if the two coin types refer to the same on-chain coin after canonicalization.
    public static func areEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        canonicalize(lhs) == canonicalize(rhs)
    }
}
