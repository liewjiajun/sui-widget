import SwiftUI

/// Placeholder. V1 Task 7 fills in settings per the Figma design.
struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                SuiGlyph(size: 64)
                Text("Settings")
                    .font(SuiTypography.display(28))
                Text("Settings UI lands in V1 Task 7")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
