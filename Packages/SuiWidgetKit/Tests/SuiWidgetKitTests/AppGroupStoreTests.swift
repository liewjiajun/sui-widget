import Foundation
import Testing
@testable import SuiWidgetKit

@Suite("AppGroupStore")
struct AppGroupStoreTests {

    @Test("round-trips a handshake value through a file in the container")
    func roundTripsHandshakeValue() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        try store.writeHandshake("test-value")

        let read = try store.readHandshake()
        #expect(read?.value == "test-value")
    }

    @Test("returns nil when no handshake file has been written")
    func returnsNilWhenAbsent() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppGroupStore(containerURL: dir)
        #expect(try store.readHandshake() == nil)
    }
}
