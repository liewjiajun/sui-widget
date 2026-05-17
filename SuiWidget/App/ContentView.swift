import SwiftUI
import SuiWidgetKit
import WidgetKit

struct ContentView: View {
    @State private var lastWritten: HandshakePayload?
    @State private var lastRead: HandshakePayload?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("App Group handshake")
                .font(.headline)

            row(label: "Wrote:", payload: lastWritten)
            row(label: "Read back:", payload: lastRead)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            }

            Button("Write again", action: writeAndReload)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { writeAndReload() }
    }

    @ViewBuilder
    private func row(label: String, payload: HandshakePayload?) -> some View {
        HStack(alignment: .top) {
            Text(label).bold()
            Text(payload?.value ?? "—")
                .monospaced()
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }

    private func writeAndReload() {
        do {
            let store = try AppGroupStore()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let value = "hello-\(timestamp)"
            let payload = HandshakePayload(value: value, writtenAt: Date())
            try store.writeHandshake(value)
            lastWritten = payload
            lastRead = try store.readHandshake()
            WidgetCenter.shared.reloadAllTimelines()
            errorMessage = nil
        } catch {
            errorMessage = "AppGroupStore error: \(error)"
        }
    }
}

#Preview {
    ContentView()
}
