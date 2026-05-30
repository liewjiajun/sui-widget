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
            // Decode element-wise so one malformed market entry doesn't abort the
            // whole batch (mirrors the lenient NFT-page decoding). A dropped entry
            // simply leaves that token unpriced for the cycle.
            let failable = try JSONDecoder().decode([FailableDecodable<CoinGeckoMarket>].self, from: data)
            return failable.compactMap(\.value)
        } catch {
            throw CoinGeckoError.decodingFailed(detail: String(describing: error))
        }
    }

    /// Historical price chart for a single CoinGecko id. Sui Widget uses this to
    /// render the 7-day spark chart on TokenDetailView. `days` ≥ 2 selects the
    /// hourly interval; sub-day requests use the 5-minute interval.
    public func fetchMarketChart(coingeckoId: String, days: Int = 7) async throws -> CoinGeckoMarketChart {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent("coins/\(coingeckoId)/market_chart"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: "\(days)"),
            URLQueryItem(name: "interval", value: days >= 2 ? "hourly" : "5m"),
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
            return try JSONDecoder().decode(CoinGeckoMarketChart.self, from: data)
        } catch {
            throw CoinGeckoError.decodingFailed(detail: String(describing: error))
        }
    }

    /// USD→fiat rates for the given ISO codes (e.g. ["EUR","SGD"]), derived from
    /// USD-Coin's price in each currency (USDC is pegged ~1:1 to USD, so its
    /// price in EUR *is* the USD→EUR rate). Returns `[code: rate]` uppercased.
    /// Used by `FXRateStore` to present USD-denominated portfolios in the user's
    /// chosen display currency.
    public func fetchFiatRatesVsUSD(codes: [String]) async throws -> [String: Double] {
        let lowered = codes.map { $0.lowercased() }.filter { $0 != "usd" }
        guard !lowered.isEmpty else { return [:] }

        var components = URLComponents(url: Self.baseURL.appendingPathComponent("simple/price"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ids", value: "usd-coin"),
            URLQueryItem(name: "vs_currencies", value: lowered.joined(separator: ",")),
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

        // Shape: { "usd-coin": { "eur": 0.92, "sgd": 1.34, ... } }
        let decoded: [String: [String: Double]]
        do {
            decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        } catch {
            throw CoinGeckoError.decodingFailed(detail: String(describing: error))
        }
        guard let byCurrency = decoded["usd-coin"] else { return [:] }
        var result: [String: Double] = [:]
        for (k, v) in byCurrency where v > 0 {
            result[k.uppercased()] = v
        }
        return result
    }

    // MARK: - Internal helpers

    private func fetchOrCreateAppSettings() throws -> AppSettings {
        // Routed through the singleton helper so app / widget / background
        // contexts all converge on one AppSettings row.
        AppSettings.current(in: modelContext)
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
