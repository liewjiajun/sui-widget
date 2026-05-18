import SwiftUI
import SuiWidgetKit

struct NewsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NewsViewModel?
    @State private var browserURL: NewsBrowserURL?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
                    .refreshable { await viewModel.refresh() }
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = NewsViewModel(modelContext: modelContext)
                        viewModel?.load()
                    }
            }
        }
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $browserURL) { wrapper in
            SafariView(url: wrapper.url)
        }
    }

    @ViewBuilder
    private func content(viewModel: NewsViewModel) -> some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s3) {
                if case .empty(let message) = viewModel.loadState, viewModel.items.isEmpty {
                    Spacer().frame(height: SuiSpacing.s5)
                    VStack(spacing: SuiSpacing.s3) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(message)
                            .font(SuiTypography.body(13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    if let featured = viewModel.featured {
                        Button(action: { browserURL = NewsBrowserURL(url: URL(string: featured.url)!) }) {
                            NewsRowView(item: featured, isFeatured: true)
                        }
                        .buttonStyle(.plain)
                    }
                    if !viewModel.rest.isEmpty {
                        Text("MORE")
                            .font(SuiTypography.mono(10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, SuiSpacing.s3)
                        ForEach(viewModel.rest, id: \.id) { item in
                            Button(action: { browserURL = NewsBrowserURL(url: URL(string: item.url)!) }) {
                                NewsRowView(item: item, isFeatured: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
