import Foundation

public enum NewsSource: String, Codable, CaseIterable, Sendable {
    case blog
    case githubRelease = "github_release"
}
