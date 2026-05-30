import Foundation

public enum NewsSource: String, Codable, CaseIterable, Sendable {
    case blog
    case githubRelease = "github_release"
    /// Fallback for any persisted/decoded value outside the known set, so a
    /// stale SwiftData row or a future feed source decodes safely instead of
    /// throwing (which, inside a `[CachedNewsItem]` fetch, would surface as
    /// lost news rows or a hard error).
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsSource(rawValue: raw) ?? .unknown
    }

    /// Short human label for chips/captions.
    public var displayLabel: String {
        switch self {
        case .blog: return "Sui Blog"
        case .githubRelease: return "GitHub"
        case .unknown: return "News"
        }
    }
}
