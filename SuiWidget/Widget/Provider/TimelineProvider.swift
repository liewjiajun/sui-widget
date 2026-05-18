import WidgetKit
import SuiWidgetKit

struct HandshakeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HandshakeEntry {
        HandshakeEntry(date: Date(), handshakeValue: "—")
    }

    func getSnapshot(in context: Context, completion: @escaping (HandshakeEntry) -> Void) {
        Task {
            let entry = await currentEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HandshakeEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            let nextRefresh = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func currentEntry() async -> HandshakeEntry {
        let value: String
        do {
            value = try await AppGroupStore().readHandshake()?.value ?? "(no value)"
        } catch {
            value = "(no value)"
        }
        return HandshakeEntry(date: Date(), handshakeValue: value)
    }
}
