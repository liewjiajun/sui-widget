import Foundation
import SwiftData

public struct CoinGeckoClient {
    public static let baseURL = URL(string: "https://api.coingecko.com/api/v3")!

    public let http: HTTPClient
    public let modelContext: ModelContext
    /// 24-hour cache TTL for the coin list. Configurable for tests.
    public let coinListTTL: TimeInterval
    /// Clock injected for deterministic TTL tests.
    public let clock: InjectableClock

    public init(
        http: HTTPClient = HTTPClient(),
        modelContext: ModelContext,
        coinListTTL: TimeInterval = 24 * 60 * 60,
        clock: InjectableClock = .system
    ) {
        self.http = http
        self.modelContext = modelContext
        self.coinListTTL = coinListTTL
        self.clock = clock
    }

    /// Refreshes the Sui-coin → CoinGecko-id mapping. If the on-disk cache is
    /// fresher than `coinListTTL`, returns the persisted mapping without a network call.
    /// On a fresh fetch, deletes prior `CachedCoinListEntry` rows and inserts fresh ones,
    /// updating `AppSettings.lastCoinListFetchedAt`.
    public func refreshCoinList(force: Bool = false) async throws -> [CoinTypeMapping] {
        let settings = try fetchOrCreateAppSettings()
        let now = clock.now()
        if !force,
           let lastFetch = settings.lastCoinListFetchedAt,
           now.timeIntervalSince(lastFetch) < coinListTTL {
            return try fetchCachedMappings()
        }

        var components = URLComponents(url: Self.baseURL.appendingPathComponent("coins/list"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "include_platform", value: "true")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await http.send(request)
        } catch let err as HTTPClientError {
            if case .exhausted(let status, _) = err, status == 429 {
                throw CoinGeckoError.rateLimitExceeded
            }
            throw CoinGeckoError.http(err)
        }

        guard (200...299).contains(response.statusCode) else {
            throw CoinGeckoError.http(.clientError(response.statusCode))
        }

        let allEntries: [CoinGeckoListEntry]
        do {
            allEntries = try JSONDecoder().decode([CoinGeckoListEntry].self, from: data)
        } catch {
            throw CoinGeckoError.decodingFailed(detail: String(describing: error))
        }

        // Filter to Sui-platform entries. Canonicalize coinType so the persisted
        // mapping always uses the long-form (0x0000…) representation that matches
        // what other on-chain sources emit after canonicalization.
        let mappings: [CoinTypeMapping] = allEntries.compactMap { entry in
            guard let coinType = entry.suiCoinType else { return nil }
            return CoinTypeMapping(
                coinType: CoinTypeCanonicalizer.canonicalize(coinType),
                coingeckoId: entry.id,
                symbol: entry.symbol,
                name: entry.name
            )
        }

        // Replace persisted rows.
        let existing = try modelContext.fetch(FetchDescriptor<CachedCoinListEntry>())
        for row in existing { modelContext.delete(row) }
        for mapping in mappings {
            modelContext.insert(CachedCoinListEntry(
                coinType: mapping.coinType,
                coingeckoId: mapping.coingeckoId,
                symbol: mapping.symbol,
                name: mapping.name
            ))
        }
        settings.lastCoinListFetchedAt = now
        try modelContext.save()

        return mappings
    }

    /// Batched price + 24h change for a list of CoinGecko IDs.
    /// IDs are CoinGecko's own ids (e.g. "sui", "usd-coin"), NOT coin types.
    /// Caller is responsible for the coinType → id lookup via the coin list cache.
    public func fetchPrices(coingeckoIds: [String]) async throws -> [CoinGeckoMarket] {
        guard !coingeckoIds.isEmpty else { return [] }

        var components = URLComponents(url: Self.baseURL.appendingPathComponent("coins/markets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "ids", value: coingeckoIds.joined(separator: ",")),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await http.send(request)
        } catch let err as HTTPClientError {
            if case .exhausted(let status, _) = err, status == 429 {
                throw CoinGeckoError.rateLimitExceeded
            }
            throw CoinGeckoError.http(err)
        }

        guard (200...299).contains(response.statusCode) else {
            throw CoinGeckoError.http(.clientError(response.statusCode))
        }

        do {
            return try JSONDecoder().decode([CoinGeckoMarket].self, from: data)
        } catch {
            throw CoinGeckoError.decodingFailed(detail: String(describing: error))
        }
    }

    // MARK: - Internal helpers

    private func fetchOrCreateAppSettings() throws -> AppSettings {
        let existing = try modelContext.fetch(FetchDescriptor<AppSettings>())
        if let s = existing.first { return s }
        let new = AppSettings()
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    private func fetchCachedMappings() throws -> [CoinTypeMapping] {
        let rows = try modelContext.fetch(FetchDescriptor<CachedCoinListEntry>())
        return rows.map { CoinTypeMapping(
            coinType: $0.coinType,
            coingeckoId: $0.coingeckoId,
            symbol: $0.symbol,
            name: $0.name
        )}
    }
}
