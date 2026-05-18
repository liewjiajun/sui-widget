import SwiftUI
import SuiWidgetKit

struct NewsRowView: View {
    let item: CachedNewsItem
    let isFeatured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            if isFeatured {
                featuredHero
            }
            HStack(alignment: .top, spacing: SuiSpacing.s2) {
                sourcePill
                if !isFeatured {
                    Spacer()
                    Text(timeAgoLabel)
                        .font(SuiTypography.mono(9))
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.title)
                .font(SuiTypography.body(isFeatured ? 16 : 13, weight: .semibold))
                .lineLimit(isFeatured ? 3 : 2)
                .multilineTextAlignment(.leading)
            if let summary = item.summary, isFeatured {
                Text(summary.replacingOccurrences(of: "\n", with: " "))
                    .font(SuiTypography.body(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if isFeatured {
                HStack(spacing: SuiSpacing.s2) {
                    Text("FEATURED").font(SuiTypography.mono(9, weight: .bold))
                    Text("·").foregroundStyle(.secondary)
                    Text(timeAgoLabel).font(SuiTypography.mono(9))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(isFeatured ? SuiSpacing.s4 : SuiSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var featuredHero: some View {
        RoundedRectangle(cornerRadius: SuiSpacing.cardRadius - 2, style: .continuous)
            .fill(SuiColor.suiBlue.opacity(0.18))
            .frame(height: 140)
            .overlay(
                Image(systemName: heroSystemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(SuiColor.suiBlue)
            )
    }

    private var heroSystemImage: String {
        switch item.source {
        case .blog: return "newspaper"
        case .githubRelease: return "shippingbox"
        }
    }

    private var sourcePill: some View {
        Text(item.source == .blog ? "BLOG" : "RELEASE")
            .font(SuiTypography.mono(9, weight: .bold))
            .padding(.horizontal, SuiSpacing.s2)
            .padding(.vertical, 2)
            .background(Capsule().fill(SuiColor.suiBlue.opacity(0.18)))
            .foregroundStyle(SuiColor.suiBlue)
    }

    private var timeAgoLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.publishedAt, relativeTo: Date())
    }
}
