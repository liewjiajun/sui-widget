import Foundation
import SwiftData

public struct SuiNSResolver {
    public let rpc: SuiRPCClient
    public let modelContext: ModelContext
    public let cacheTTL: TimeInterval
    public let clock: InjectableClock

    public init(
        rpc: SuiRPCClient = SuiRPCClient(),
        modelContext: ModelContext,
        cacheTTL: TimeInterval = 60 * 60,         // 1 hour
        clock: InjectableClock = .system
    ) {
        self.rpc = rpc
        self.modelContext = modelContext
        self.cacheTTL = cacheTTL
        self.clock = clock
    }

    /// Accepts:
    /// - `0x...` (returned as-is after validation)
    /// - `name.sui` (forward lookup with cache)
    /// - `@name` (treated as `name.sui` then forward lookup)
    public func resolve(_ input: String) async throws -> SuiAddress {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x") {
            guard let addr = SuiAddress(rawValue: trimmed) else {
                throw SuiNSError.invalidAddress(trimmed)
            }
            return addr
        }

        // Normalize to canonical name: lowercase, drop leading @, ensure .sui suffix.
        let stripped = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let lower = stripped.lowercased()
        let canonical: String
        if lower.hasSuffix(".sui") {
            canonical = lower
        } else if !lower.contains(".") {
            canonical = lower + ".sui"
        } else {
            throw SuiNSError.invalidName(trimmed)
        }

        // Check cache.
        let now = clock.now()
        let cached = try fetchCachedResolution(name: canonical)
        if let cached, now.timeIntervalSince(cached.cachedAt) < cacheTTL {
            guard let addr = SuiAddress(rawValue: cached.address) else {
                throw SuiNSError.invalidAddress(cached.address)
            }
            return addr
        }

        // Resolve via RPC.
        let resolved: SuiAddress?
        do {
            resolved = try await rpc.resolveNameServiceAddress(name: canonical)
        } catch SuiRPCError.missingResult {
            // suix_resolveNameServiceAddress returns `result: null` for unregistered
            // names; SuiRPCClient surfaces this as .missingResult. Treat as not-found.
            throw SuiNSError.nameNotFound(canonical)
        } catch let suiErr as SuiRPCError {
            throw SuiNSError.rpc(suiErr)
        }
        guard let address = resolved else {
            throw SuiNSError.nameNotFound(canonical)
        }

        // Upsert.
        if let cached {
            cached.address = address.rawValue
            cached.cachedAt = now
        } else {
            modelContext.insert(CachedSuiNSResolution(
                name: canonical,
                address: address.rawValue,
                cachedAt: now
            ))
        }
        try modelContext.save()
        return address
    }

    /// Reverse-resolves an address to its first SuiNS name, or nil if none registered.
    ///
    /// Cached in `CachedSuiNSReverse` (keyed by address) — NEVER in the forward
    /// (`CachedSuiNSResolution`) table. Forward (name→address) and reverse
    /// (address→name) lookups are not guaranteed inverses, so writing a reverse
    /// result into the forward cache could make a later `resolve(name)` return an
    /// address the name doesn't actually point to (see CachedSuiNSReverse).
    public func reverseResolve(address: SuiAddress) async throws -> String? {
        let now = clock.now()
        if let cached = try fetchCachedReverse(address: address.rawValue),
           now.timeIntervalSince(cached.resolvedAt) < cacheTTL {
            return cached.name
        }
        do {
            let names = try await rpc.resolveNameServiceNames(address: address)
            guard let first = names.first else { return nil }
            let canonical = first.lowercased()
            if let cached = try fetchCachedReverse(address: address.rawValue) {
                cached.name = canonical
                cached.resolvedAt = now
            } else {
                modelContext.insert(CachedSuiNSReverse(
                    address: address.rawValue,
                    name: canonical,
                    resolvedAt: now
                ))
            }
            try modelContext.save()
            return canonical
        } catch let suiErr as SuiRPCError {
            throw SuiNSError.rpc(suiErr)
        }
    }

    // MARK: - Internal helpers

    private func fetchCachedResolution(name: String) throws -> CachedSuiNSResolution? {
        var descriptor = FetchDescriptor<CachedSuiNSResolution>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchCachedReverse(address: String) throws -> CachedSuiNSReverse? {
        var descriptor = FetchDescriptor<CachedSuiNSReverse>(
            predicate: #Predicate { $0.address == address }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
