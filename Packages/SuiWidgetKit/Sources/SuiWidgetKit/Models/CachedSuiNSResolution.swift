import Foundation
import SwiftData

/// Cached forward resolution of a SuiNS name to its 0x address. Names are stored
/// lowercased without the leading "@" (always ".sui"-suffixed). 1h TTL via `cachedAt`.
@Model
public final class CachedSuiNSResolution {
    @Attribute(.unique) public var name: String       // e.g. "alice.sui"
    public var address: String                         // resolved 0x...
    public var cachedAt: Date

    public init(name: String, address: String, cachedAt: Date = Date()) {
        self.name = name
        self.address = address
        self.cachedAt = cachedAt
    }
}
