import Foundation
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class WidgetConfigViewModel {
    var selectedFamily: WidgetFamilyOption = .small
    var walletScope: WalletScopeOption = .primary
    var refresh: RefreshFrequencyOption = .auto
    var currency: CurrencyOption = .usd
    var variant: WidgetVariantOption = .default
    var walletDisplay: WalletIdentifierDisplayOption = .suiNSName

    /// Constructs a SuiWidgetConfigurationIntent populated with the current selections,
    /// for use in the live preview.
    var previewIntent: SuiWidgetConfigurationIntent {
        let intent = SuiWidgetConfigurationIntent()
        intent.walletScope = walletScope
        intent.refresh = refresh
        intent.currency = currency
        intent.variant = variant
        intent.walletDisplay = walletDisplay
        return intent
    }
}

/// The widget family the user is configuring in the preview. Distinct from
/// WidgetFamily (WidgetKit's enum) — this drives our UI picker.
enum WidgetFamilyOption: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge
    case lockInline = "lock_inline"
    case lockCircular = "lock_circular"
    case lockRectangular = "lock_rectangular"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        case .lockInline: return "Lock Inline"
        case .lockCircular: return "Lock Circular"
        case .lockRectangular: return "Lock Rectangular"
        }
    }

    var iconSystemName: String {
        switch self {
        case .small: return "square"
        case .medium: return "rectangle"
        case .large: return "rectangle.portrait"
        case .extraLarge: return "rectangle.fill"
        case .lockInline: return "lock.rectangle"
        case .lockCircular: return "lock.circle"
        case .lockRectangular: return "lock"
        }
    }
}
