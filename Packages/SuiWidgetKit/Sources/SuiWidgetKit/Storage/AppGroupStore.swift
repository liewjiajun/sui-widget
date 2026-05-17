import Foundation

/// File-based shared store for values that must round-trip between the main
/// app and the widget extension via the `group.io.sui.widget` App Group container.
///
/// Phase 0 uses this for a single handshake value. Phase 1+ adds typed accessors
/// (cached portfolio JSON snapshot, last-refresh timestamp, etc.).
public struct AppGroupStore {

    /// The shared App Group identifier. Mirrored in the entitlement files for both targets.
    public static let groupIdentifier = "group.io.sui.widget"

    /// Filename of the handshake JSON inside the container.
    public static let handshakeFilename = "handshake.json"

    private let containerURL: URL

    /// Production initializer — uses the App Group container.
    /// Throws `AppGroupStoreError.containerUnavailable` when running outside an entitled target.
    public init() throws {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.groupIdentifier
        ) else {
            throw AppGroupStoreError.containerUnavailable
        }
        self.containerURL = url
    }

    /// Test initializer — uses an injected directory instead of the entitlement-backed container.
    public init(containerURL: URL) {
        self.containerURL = containerURL
    }

    /// Absolute URL of the handshake file inside the container.
    public var handshakeURL: URL {
        containerURL.appendingPathComponent(Self.handshakeFilename)
    }

    /// Writes a `HandshakePayload` containing `value` and the current timestamp.
    public func writeHandshake(_ value: String) throws {
        let payload = HandshakePayload(value: value, writtenAt: Date())
        let data = try JSONEncoder().encode(payload)
        try data.write(to: handshakeURL, options: .atomic)
    }

    /// Reads the most recent handshake payload, or `nil` if none has been written.
    public func readHandshake() throws -> HandshakePayload? {
        guard FileManager.default.fileExists(atPath: handshakeURL.path) else { return nil }
        let data = try Data(contentsOf: handshakeURL)
        return try JSONDecoder().decode(HandshakePayload.self, from: data)
    }
}

/// Serializable payload written by `AppGroupStore.writeHandshake(_:)`.
public struct HandshakePayload: Codable, Equatable {
    public let value: String
    public let writtenAt: Date

    public init(value: String, writtenAt: Date) {
        self.value = value
        self.writtenAt = writtenAt
    }
}

public enum AppGroupStoreError: Error {
    case containerUnavailable
}
