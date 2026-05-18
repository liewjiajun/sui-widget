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
        // Prefer the cached App-Group thumbnail when the file actually exists
        // on disk. Raw filesystem paths must use URL(fileURLWithPath:) — the
        // previous URL(string:) form silently produced nil for absolute paths
        // without a scheme, which suppressed the remote-image fallback and left
        // the grid showing initials when the cache was missing.
        if let path = nft.thumbnailFilePath,
           FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    remoteOrFallback
                case .empty:
                    remoteOrFallback
                @unknown default:
                    remoteOrFallback
                }
            }
        } else {
            remoteOrFallback
        }
    }

    @ViewBuilder
    private var remoteOrFallback: some View {
        if let url = URL(string: nft.imageURL), !nft.imageURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    fallback.overlay(ProgressView().controlSize(.small))
                case .failure:
                    fallback
                @unknown default:
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
