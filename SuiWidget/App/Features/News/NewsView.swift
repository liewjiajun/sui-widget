import SwiftUI

/// Placeholder. V1 Task 6 fills in news feed with in-app browser per the Figma design.
struct NewsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                SuiGlyph(size: 64)
                Text("News")
                    .font(SuiTypography.display(28))
                Text("News feed + in-app browser lands in V1 Task 6")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.large)
    }
}
