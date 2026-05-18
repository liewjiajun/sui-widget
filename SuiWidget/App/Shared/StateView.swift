import SwiftUI
import SuiWidgetKit

public enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case empty(message: String)
    case error(message: String, retry: (@Sendable () -> Void)? = nil)
    case stale(staleSince: Date)
    case offline

    public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.offline, .offline):
            return true
        case (.empty(let a), .empty(let b)): return a == b
        case (.error(let a, _), .error(let b, _)): return a == b
        case (.stale(let a), .stale(let b)): return a == b
        default: return false
        }
    }
}

/// Wraps content with state-aware overlays (loading skeleton, empty CTA, error pill).
public struct StateView<Content: View, Skeleton: View>: View {
    public let state: LoadState
    @ViewBuilder public let content: () -> Content
    @ViewBuilder public let skeleton: () -> Skeleton

    public init(
        state: LoadState,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder skeleton: @escaping () -> Skeleton
    ) {
        self.state = state
        self.content = content
        self.skeleton = skeleton
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            switch state {
            case .idle, .loaded:
                content()
            case .loading:
                skeleton().redacted(reason: .placeholder)
            case .empty(let message):
                emptyView(message: message)
            case .error(let message, let retry):
                errorContent(message: message, retry: retry)
            case .stale:
                content()
                stalePill
            case .offline:
                content()
                offlinePill
            }
        }
    }

    @ViewBuilder
    private func emptyView(message: String) -> some View {
        VStack(spacing: SuiSpacing.s3) {
            Text(message)
                .font(SuiTypography.body(15))
                .multilineTextAlignment(.center)
            // Caller can layer a CTA on top by switching to .loaded after action.
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorContent(message: String, retry: (@Sendable () -> Void)?) -> some View {
        VStack(spacing: SuiSpacing.s2) {
            content().opacity(0.5)
            HStack(spacing: SuiSpacing.s2) {
                Text("⚠")
                Text(message).font(SuiTypography.body(12))
                if let retry {
                    Button("tap retry") { retry() }
                        .font(SuiTypography.body(12, weight: .semibold))
                }
            }
            .padding(.horizontal, SuiSpacing.s3)
            .padding(.vertical, SuiSpacing.s2)
            .background(Capsule().fill(SuiColor.coral.opacity(0.18)))
        }
    }

    private var stalePill: some View {
        HStack(spacing: SuiSpacing.s1) {
            Text("⌛")
            Text("stale").font(SuiTypography.mono(10, weight: .bold))
        }
        .padding(.horizontal, SuiSpacing.s2)
        .padding(.vertical, SuiSpacing.s1)
        .background(Capsule().fill(SuiColor.amber.opacity(0.18)))
        .padding(SuiSpacing.s2)
    }

    private var offlinePill: some View {
        HStack(spacing: SuiSpacing.s1) {
            Text("📡")
            Text("offline").font(SuiTypography.mono(10, weight: .bold))
        }
        .padding(.horizontal, SuiSpacing.s2)
        .padding(.vertical, SuiSpacing.s1)
        .background(Capsule().fill(SuiColor.flat.opacity(0.18)))
        .padding(SuiSpacing.s2)
    }
}
