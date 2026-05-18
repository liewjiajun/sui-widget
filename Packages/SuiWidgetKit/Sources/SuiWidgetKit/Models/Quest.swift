import Foundation
import SwiftData

/// V3 stub — quest entity. Not active in V1; never instantiated, never registered
/// in SwiftDataStack.schema. Reserved here so the file path is stable for V3.
@Model
public final class Quest {
    @Attribute(.unique) public var questId: String
    public var title: String
    public var summary: String
    public var xpReward: Int
    public var status: QuestStatus
    public var expiresAt: Date?

    public init(
        questId: String,
        title: String,
        summary: String,
        xpReward: Int,
        status: QuestStatus = .available,
        expiresAt: Date? = nil
    ) {
        self.questId = questId
        self.title = title
        self.summary = summary
        self.xpReward = xpReward
        self.status = status
        self.expiresAt = expiresAt
    }
}
