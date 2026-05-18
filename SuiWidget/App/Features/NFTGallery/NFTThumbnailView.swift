import SwiftUI
import SuiWidgetKit

struct NFTThumbnailView: View {
    let nft: CachedNFTItem
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            if nft.showInWidget {
                badge
                    .padding(4)
            }
        }
        .accessibilityLabel("\(nft.name)\(nft.showInWidget ? ", in widget" : "")")
    }

    @ViewBuilder
    private var background: some View {
        if let path = nft.thumbnailFilePath, let url = URL(string: path) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    fallback
                }
            }
        } else if let url = URL(string: nft.imageURL) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SuiColor.suiBlue.opacity(0.18))
            Text(String(nft.name.prefix(2)))
                .font(SuiTypography.display(14))
                .foregroundStyle(SuiColor.suiDeep)
        }
    }

    private var badge: some View {
        ZStack {
            Circle().fill(SuiColor.up)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 18, height: 18)
    }
}
