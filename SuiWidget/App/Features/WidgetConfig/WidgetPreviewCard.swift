import SwiftUI
import SuiWidgetKit

/// Live preview wrapper. Shows the selected widget variant at native size with
/// the .preview entry.
struct WidgetPreviewCard: View {
    let family: WidgetFamilyOption
    let intent: SuiWidgetConfigurationIntent

    var body: some View {
        VStack(spacing: SuiSpacing.s3) {
            Text("PREVIEW")
                .font(SuiTypography.mono(9, weight: .bold))
                .foregroundStyle(.secondary)
            preview
                .background(
                    RoundedRectangle(cornerRadius: SuiSpacing.widgetRadius, style: .continuous)
                        .fill(SuiColor.suiBlue.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: SuiSpacing.widgetRadius, style: .continuous))
                .pixelLift()
        }
    }

    @ViewBuilder
    private var preview: some View {
        let entry = SuiWidgetEntry.preview
        switch family {
        case .small:
            SmallWidgetView(entry: entry).frame(width: 170, height: 170)
        case .medium:
            MediumWidgetView(entry: entry).frame(width: 340, height: 170)
        case .large:
            LargeWidgetView(entry: entry).frame(width: 340, height: 340).clipped()
        case .extraLarge:
            ExtraLargeWidgetView(entry: entry).frame(width: 340, height: 170).clipped()
        case .lockInline:
            InlineWidgetView(entry: entry)
                .frame(maxWidth: 240, alignment: .leading)
                .padding(SuiSpacing.s2)
                .background(Color.black.opacity(0.6))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        case .lockCircular:
            CircularWidgetView(entry: entry)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color.black.opacity(0.6)))
                .foregroundStyle(.white)
        case .lockRectangular:
            RectangularWidgetView(entry: entry)
                .frame(width: 172, height: 76)
                .padding(SuiSpacing.s2)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.6)))
                .foregroundStyle(.white)
        }
    }
}
