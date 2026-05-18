import Foundation

/// Tiny clock abstraction so the rotator's "5 minute ago" check is testable
/// without sleeping. Production callers use `.system`; tests use `.fixed(_:)`
/// or `.advancing(start:by:)`.
public struct InjectableClock: Sendable {
    public let now: @Sendable () -> Date

    public init(now: @Sendable @escaping () -> Date) {
        self.now = now
    }

    public static let system = InjectableClock { Date() }

    /// Always returns the given fixed date. Useful when no clock movement is needed.
    public static func fixed(_ date: Date) -> InjectableClock {
        InjectableClock { date }
    }
}
