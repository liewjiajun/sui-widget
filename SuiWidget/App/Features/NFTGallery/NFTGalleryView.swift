import SwiftUI
import SwiftData
import SuiWidgetKit

struct NFTGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NFTGalleryViewModel?

    private let columns = [
        GridItem(.flexible(), spacing: SuiSpacing.s2),
        GridItem(.flexible(), spacing: SuiSpacing.s2),
        GridItem(.flexible(), spacing: SuiSpacing.s2),
    ]

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
                    .refreshable { await viewModel.refresh() }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("NFTs")
        .navigationBarTitleDisplayMode(.large)
        // The `.onAppear` lives on the outer Group so it fires every time the
        // tab becomes visible (not just on first creation). `load()` is
        // idempotent — it re-fetches the wallet list and re-groups the cached
        // NFTs, so adding a wallet in Settings → Wallets shows up here without
        // a relaunch.
        .onAppear {
            if viewModel == nil {
                viewModel = NFTGalleryViewModel(modelContext: modelContext)
            }
            viewModel?.load()
            // First entry after adding a wallet: cache is empty, so kick off
            // an RPC refresh in the background instead of forcing the user to
            // pull-to-refresh to discover their NFTs.
            viewModel?.refreshIfEmpty()
        }
    }

    @ViewBuilder
    private func content(viewModel: NFTGalleryViewModel) -> some View {
        switch viewModel.loadState {
        case .empty(let message):
            VStack(spacing: SuiSpacing.s4) {
                if let error = viewModel.refreshError {
                    refreshWarningBanner(message: error)
                        .padding(.horizontal)
                        .padding(.top, SuiSpacing.s3)
                }
                Spacer()
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        case .loading where viewModel.collections.isEmpty:
            ProgressView("Loading NFTs…").frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SuiSpacing.s5) {
                    if let error = viewModel.refreshError {
                        refreshWarningBanner(message: error)
                    }
                    ForEach(viewModel.collections) { collection in
                        collectionSection(collection: collection, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
    }

    /// Inline coral banner so partial NFT refresh failures (RPC timeout,
    /// portfolio dependency, etc.) are visible instead of silently leaving the
    /// gallery empty.
    private func refreshWarningBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: SuiSpacing.s2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(SuiTypography.body(12))
                .foregroundStyle(SuiColor.coral)
            Text(message)
                .font(SuiTypography.mono(11))
                .foregroundStyle(SuiColor.coral)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(SuiSpacing.s2)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(SuiColor.coral.opacity(0.10))
        )
    }

    @ViewBuilder
    private func collectionSection(collection: NFTGalleryViewModel.Collection, viewModel: NFTGalleryViewModel) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(collection.name)
                        .font(SuiTypography.body(14, weight: .semibold))
                    Text("\(collection.nfts.count) " + (collection.nfts.count == 1 ? "item" : "items"))
                        .font(SuiTypography.mono(10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("In widget", isOn: Binding(
                    get: { collection.nfts.allSatisfy(\.showInWidget) },
                    set: { _ in viewModel.toggleInWidget(for: collection) }
                ))
                .labelsHidden()
                .tint(SuiColor.up)
                Text("in widget").font(SuiTypography.mono(9, weight: .bold)).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: SuiSpacing.s2) {
                ForEach(Array(collection.nfts.enumerated()), id: \.element.objectId) { offset, nft in
                    NavigationLink {
                        NFTDetailView(nft: nft, onToggleInWidget: { viewModel.toggleNFTInWidget(nft) })
                    } label: {
                        NFTThumbnailView(nft: nft, size: 80)
                            .modifier(NFTAppearAnimation(delay: Double(offset) * 0.030))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Fades + slightly scales thumbnails on appear with a staggered per-item delay.
/// Keeps the LazyVGrid feel snappy without overpowering the eye on large grids.
private struct NFTAppearAnimation: ViewModifier {
    let delay: Double
    @State private var visible: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.85)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(delay)) {
                    visible = true
                }
            }
    }
}
