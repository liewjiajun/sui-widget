import SwiftUI
import SafariServices
import SuiWidgetKit

struct NFTDetailView: View {
    let nft: CachedNFTItem
    let onToggleInWidget: () -> Void
    @State private var safariURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                heroImage
                VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                    Text(nft.name)
                        .font(SuiTypography.display(22))
                    if let collection = nft.collectionName {
                        Text(collection)
                            .font(SuiTypography.body(13))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                toggleCard
                attributesCard
                suiscanLink
            }
        }
        .navigationTitle(nft.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { safariURL.map { URLWrapper(url: $0) } },
            set: { safariURL = $0?.url }
        )) { wrapper in
            SafariView(url: wrapper.url)
        }
    }

    private var heroImage: some View {
        ZStack {
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
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous))
        .padding(.horizontal)
    }

    private var fallback: some View {
        RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
            .fill(SuiColor.suiBlue.opacity(0.18))
            .overlay(
                Text(String(nft.name.prefix(2)))
                    .font(SuiTypography.display(48))
                    .foregroundStyle(SuiColor.suiDeep)
            )
            .aspectRatio(1, contentMode: .fit)
    }

    private var toggleCard: some View {
        Toggle(isOn: Binding(
            get: { nft.showInWidget },
            set: { _ in onToggleInWidget() }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show in widget").font(SuiTypography.body(14, weight: .semibold))
                Text("This NFT appears on Medium / Large / XL widgets when active.")
                    .font(SuiTypography.body(11))
                    .foregroundStyle(.secondary)
            }
        }
        .tint(SuiColor.up)
        .padding(SuiSpacing.s3)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private var attributesCard: some View {
        if !nft.attributes.isEmpty {
            VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                Text("ATTRIBUTES")
                    .font(SuiTypography.mono(10, weight: .bold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SuiSpacing.s2) {
                    ForEach(nft.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.uppercased())
                                .font(SuiTypography.mono(8, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(SuiTypography.body(12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .padding(SuiSpacing.s2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(SuiColor.suiBlue.opacity(0.08))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var suiscanLink: some View {
        Button(action: openSuiscan) {
            HStack {
                Text("View on Suiscan")
                    .font(SuiTypography.body(13, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
            .padding(SuiSpacing.s3)
            .background(
                RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                    .fill(SuiColor.suiBlue.opacity(0.10))
            )
            .foregroundStyle(SuiColor.suiBlue)
        }
        .padding(.horizontal)
        .padding(.bottom, SuiSpacing.s5)
    }

    private func openSuiscan() {
        let urlString = "https://suiscan.xyz/mainnet/object/\(nft.objectId)"
        if let url = URL(string: urlString) {
            safariURL = url
        }
    }
}

private struct URLWrapper: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
