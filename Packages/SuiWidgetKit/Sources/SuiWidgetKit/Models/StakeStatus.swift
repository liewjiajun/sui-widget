import Foundation

public enum StakeStatus: String, Codable, CaseIterable, Sendable {
    case active
    case pending
    case withdrawing
}
