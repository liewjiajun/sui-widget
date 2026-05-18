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
                    .onAppear {
                        viewModel = NFTGalleryViewModel(modelContext: modelContext)
                        viewModel?.load()
                    }
            }
        }
        .navigationTitle("NFTs")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func content(viewModel: NFTGalleryViewModel) -> some View {
        switch viewModel.loadState {
        case .empty(let message):
            VStack(spacing: SuiSpacing.s4) {
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
                    ForEach(viewModel.collections) { collection in
                        collectionSection(collection: collection, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
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
                ForEach(collection.nfts, id: \.objectId) { nft in
                    NavigationLink {
                        NFTDetailView(nft: nft, onToggleInWidget: { viewModel.toggleNFTInWidget(nft) })
                    } label: {
                        NFTThumbnailView(nft: nft, size: 80)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
