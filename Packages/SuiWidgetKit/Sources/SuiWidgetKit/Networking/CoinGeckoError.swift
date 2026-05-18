import Foundation

public enum CoinGeckoError: Error, LocalizedError, Equatable {
    case http(HTTPClientError)
    case decodingFailed(detail: String)
    case rateLimitExceeded
    case unexpectedShape(detail: String)

    public var errorDescription: String? {
        switch self {
        case .http(let underlying): return "CoinGecko HTTP error: \(underlying.localizedDescription)"
        case .decodingFailed(let detail): return "CoinGecko decode failed: \(detail)"
        case .rateLimitExceeded: return "CoinGecko rate limit exceeded."
        case .unexpectedShape(let detail): return "CoinGecko returned unexpected shape: \(detail)"
        }
    }
}
