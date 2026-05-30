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
            if let fileURL = ThumbnailLocator.fileURL(forStoredReference: nft.thumbnailFilePath),
               let image = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url = Self.displayURL(for: nft.imageURL) {
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

    /// First fetchable candidate URL for a (possibly IPFS) image string, or nil.
    /// AsyncImage can't load the ipfs scheme, so rewrite to an https gateway.
    private static func displayURL(for raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        return IPFSGatewayResolver().candidates(for: raw).first
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
