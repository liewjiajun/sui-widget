import WidgetKit
import SuiWidgetKit

struct HandshakeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HandshakeEntry {
        HandshakeEntry(date: Date(), handshakeValue: "—")
    }

    func getSnapshot(in context: Context, completion: @escaping (HandshakeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HandshakeEntry>) -> Void) {
        let entry = currentEntry()
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> HandshakeEntry {
        let value = (try? AppGroupStore().readHandshake()?.value) ?? "(no value)"
        return HandshakeEntry(date: Date(), handshakeValue: value)
    }
}
