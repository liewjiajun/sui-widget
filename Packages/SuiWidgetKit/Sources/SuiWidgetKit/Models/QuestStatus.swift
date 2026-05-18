import Foundation

public enum QuestStatus: String, Codable, CaseIterable, Sendable {
    case available
    case inProgress = "in_progress"
    case completed
}
