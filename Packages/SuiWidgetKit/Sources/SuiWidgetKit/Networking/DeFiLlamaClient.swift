import Foundation

/// One resolved price for a Sui coin type, from DeFiLlama's `coins.llama.fi`.
public struct DeFiLlamaPrice: Equatable, Sendable {
    /// Canonical Sui coin type (64-hex-char package form).
    public let coinType: String
    public let priceUSD: Decimal
    /// On-chain decimals reported by DeFiLlama (lets us skip a metadata RPC).
    public let decimals: Int?
    public let symbol: String?
    /// 24h percentage change, populated from the `/percentage` endpoint when available.
    public let change24h: Double?

    public init(coinType: String, priceUSD: Decimal, decimals: Int?, symbol: String?, change24h: Double?) {
        self.coinType = coinType
        self.priceUSD = priceUSD
        self.decimals = decimals
        self.symbol = symbol
        self.change24h = change24h
    }
}

/// Prices Sui tokens via DeFiLlama's free, keyless `coins.llama.fi` API.
///
/// Unlike CoinGecko (which needs a `coinType → coingecko-id` mapping step and
/// rate-limits the free tier hard), DeFiLlama is keyed **directly by Sui coin
/// type** (`sui:0x…::module::TYPE`) and has far more headroom — so it's the app's
/// primary price source, with CoinGecko kept only as a fallback for coins
/// DeFiLlama doesn't track. The API also returns the coin's decimals, sparing a
/// `suix_getCoinMetadata` round-trip for priced tokens.
public struct DeFiLlamaClient: Sendable {
    public static let baseURL = URL(string: "https://coins.llama.fi")!

    public let http: HTTPClient
    /// Max coin types per request — keeps URLs comfortably short.
    private let chunkSize = 30

    public init(http: HTTPClient = HTTPClient()) {
        self.http = http
    }

    /// Batched current price + 24h change for the given Sui coin types.
    /// Returns a map keyed by **canonical** coin type; coins DeFiLlama doesn't
    /// track are simply absent (no error). Throws only on a hard transport /
    /// decode failure of the price request, so callers can fall back.
    public func fetchPrices(coinTypes: [String]) async throws -> [String: DeFiLlamaPrice] {
        let canonical = Array(Set(coinTypes.map { CoinTypeCanonicalizer.canonicalize($0) }))
        guard !canonical.isEmpty else { return [:] }

        var result: [String: DeFiLlamaPrice] = [:]
        for chunk in canonical.chunked(into: chunkSize) {
            let prices = try await fetchPriceChunk(chunk)
            // 24h change is a best-effort enrichment — never fail the price fetch
            // because the percentage endpoint hiccuped.
            let changes = (try? await fetchChangeChunk(chunk)) ?? [:]
            for (ct, base) in prices {
                result[ct] = DeFiLlamaPrice(
                    coinType: ct,
                    priceUSD: base.priceUSD,
                    decimals: base.decimals,
                    symbol: base.symbol,
                    change24h: changes[ct]
                )
            }
        }
        return result
    }

    // MARK: - Internal

    private struct BasePrice { let priceUSD: Decimal; let decimals: Int?; let symbol: String? }

    private func fetchPriceChunk(_ canonicalTypes: [String]) async throws -> [String: BasePrice] {
        guard let url = makeURL(path: "prices/current", canonicalTypes: canonicalTypes) else { return [:] }
        let (data, response) = try await send(url)
        guard (200...299).contains(response.statusCode) else {
            throw DeFiLlamaError.http(status: response.statusCode)
        }
        // Lenient per-entry decode: one malformed coin must not void the batch.
        struct PricesEnvelope: Decodable { let coins: [String: FailableDecodable<LlamaCoin>] }
        let env: PricesEnvelope
        do {
            env = try JSONDecoder().decode(PricesEnvelope.self, from: data)
        } catch {
            throw DeFiLlamaError.decodingFailed(String(describing: error))
        }
        var out: [String: BasePrice] = [:]
        for (rawKey, wrapped) in env.coins {
            guard let coin = wrapped.value else { continue }
            let canonical = CoinTypeCanonicalizer.canonicalize(stripPrefix(rawKey))
            out[canonical] = BasePrice(
                priceUSD: Decimal(coin.price),
                decimals: coin.decimals,
                symbol: coin.symbol
            )
        }
        return out
    }

    private func fetchChangeChunk(_ canonicalTypes: [String]) async throws -> [String: Double] {
        guard var url = makeURL(path: "percentage", canonicalTypes: canonicalTypes) else { return [:] }
        // `?period=24h` selects the 24h window.
        if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = [URLQueryItem(name: "period", value: "24h")]
            if let withQuery = comps.url { url = withQuery }
        }
        let (data, response) = try await send(url)
        guard (200...299).contains(response.statusCode) else { return [:] }
        // Shape: { "coins": { "sui:0x..::T": <number-or-null> } }. Use
        // JSONSerialization so a null value for one coin doesn't break decoding.
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let coins = root["coins"] as? [String: Any] else {
            return [:]
        }
        var out: [String: Double] = [:]
        for (rawKey, value) in coins {
            if let number = value as? NSNumber {
                out[CoinTypeCanonicalizer.canonicalize(stripPrefix(rawKey))] = number.doubleValue
            }
        }
        return out
    }

    private func send(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        return try await http.send(request)
    }

    /// Builds `…/{path}/sui:<type>,sui:<type>` with the coin segment percent-
    /// encoded. `urlPathAllowed` keeps `:` and `,` (the separators) but escapes
    /// generic-type brackets `<>` so Scallop-style `MarketCoin<…>` types don't
    /// produce an invalid URL.
    private func makeURL(path: String, canonicalTypes: [String]) -> URL? {
        let joined = canonicalTypes.map { "sui:\($0)" }.joined(separator: ",")
        guard let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "\(Self.baseURL.absoluteString)/\(path)/\(encoded)")
    }

    private func stripPrefix(_ key: String) -> String {
        key.hasPrefix("sui:") ? String(key.dropFirst("sui:".count)) : key
    }
}

private struct LlamaCoin: Decodable {
    let price: Double
    let decimals: Int?
    let symbol: String?
}

public enum DeFiLlamaError: Error, Equatable {
    case http(status: Int)
    case decodingFailed(String)
}

extension Array {
    /// Splits into consecutive sub-arrays of at most `size` elements.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
