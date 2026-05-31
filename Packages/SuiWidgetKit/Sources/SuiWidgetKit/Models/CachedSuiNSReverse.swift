import Foundation
import SwiftData

/// Reverse SuiNS resolution cache (address → primary name), kept *separate* from
/// the forward cache (`CachedSuiNSResolution`, name → address).
///
/// Forward and reverse SuiNS lookups are NOT guaranteed inverses: a name can
/// point to address A while A's reverse/default record names a different label
/// (or none). Previously `reverseResolve` wrote its result into the forward
/// cache, so a later forward `resolve(name)` could return an address the name
/// does not actually point to — the user could end up tracking the wrong wallet.
/// Keeping reverse rows in their own table, keyed by address, removes that
/// cross-contamination while still avoiding repeat RPC calls.
@Model
public final class CachedSuiNSReverse {
    @Attribute(.unique) public var address: String
    public var name: String
    public var resolvedAt: Date

    public init(address: String, name: String, resolvedAt: Date) {
        self.address = address
        self.name = name
        self.resolvedAt = resolvedAt
    }
}
