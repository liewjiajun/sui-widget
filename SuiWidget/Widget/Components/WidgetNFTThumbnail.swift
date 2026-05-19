import SwiftUI
import SuiWidgetKit

/// Renders one cached NFT thumbnail inside a widget. Reads the App-Group
/// thumbnail file synchronously when present (no network), falls back to the
/// remote image URL via AsyncImage, and ultimately to the pixel-name plaque
/// the widget shipped before this turn. The plaque is also what shows during
/// AsyncImage's `.empty` phase so the widget never displays a blank tile.
struct WidgetNFTThumbnail: View {
    let nft: NFTSummary
    let size: CGFloat
    let cornerRadius: CGFloat

    init(nft: NFTSummary, size: CGFloat, cornerRadius: CGFloat = 6) {
        self.nft = nft
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let path = nft.thumbnailFilePath,
               FileManager.default.fileExists(atPath: path),
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let urlString = nft.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        plaque
                    }
                }
            } else {
                plaque
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var plaque: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(SuiColor.suiBlue.opacity(0.18))
            .overlay(
                Text(String(nft.name.prefix(2)))
                    .font(SuiTypography.mono(max(8, size * 0.20), weight: .bold))
                    .foregroundStyle(SuiColor.suiDeep)
            )
    }
}
