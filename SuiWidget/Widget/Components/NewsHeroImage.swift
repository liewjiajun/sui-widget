import SwiftUI
import SuiWidgetKit

/// Square thumbnail for a news item inside a widget. Loads the cached hero
/// image URL via AsyncImage and falls back to a tinted source-glyph if the
/// URL is missing or the load fails — widget memory is tight, so we deliberately
/// avoid in-line content extraction beyond what RSSClient already cached.
struct NewsHeroImage: View {
    let item: NewsSummary
    let size: CGFloat
    let cornerRadius: CGFloat

    init(item: NewsSummary, size: CGFloat, cornerRadius: CGFloat = 4) {
        self.item = item
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let urlString = item.heroImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var fallback: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(SuiColor.suiBlue.opacity(0.18))
            .overlay(
                Image(systemName: item.source == .blog ? "newspaper" : "shippingbox")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(SuiColor.suiBlue)
            )
    }
}
