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
        if let url = ThumbnailLocator.fileURL(forStoredReference: nft.thumbnailFilePath) {
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
        // Rewrite ipfs:// (and gateway-prefixed) URLs to a fetchable https gateway
        // before handing them to AsyncImage — AsyncImage cannot load the ipfs
        // scheme, so a raw ipfs:// URL silently fell through to the initials
        // placeholder even when the image existed.
        if let url = Self.displayURL(for: nft.imageURL) {
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

    /// First fetchable candidate URL for a (possibly IPFS) image string, or nil.
    private static func displayURL(for raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        return IPFSGatewayResolver().candidates(for: raw).first
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
