import SwiftUI

/// Placeholder. V1 Task 5 fills in NFT gallery with show-in-widget toggle per the Figma design.
struct NFTGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                SuiGlyph(size: 64)
                Text("NFTs")
                    .font(SuiTypography.display(28))
                Text("Gallery + show-in-widget toggle lands in V1 Task 5")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("NFTs")
        .navigationBarTitleDisplayMode(.large)
    }
}
