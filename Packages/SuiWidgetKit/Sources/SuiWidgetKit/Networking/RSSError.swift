import Foundation

public enum RSSError: Error, LocalizedError, Equatable {
    case http(HTTPClientError)
    case parseFailed(detail: String)
    case noEntries

    public var errorDescription: String? {
        switch self {
        case .http(let underlying): return "RSS HTTP error: \(underlying.localizedDescription)"
        case .parseFailed(let detail): return "RSS parse failed: \(detail)"
        case .noEntries: return "RSS feed had no entries."
        }
    }
}
