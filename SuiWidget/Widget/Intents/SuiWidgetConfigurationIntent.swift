import AppIntents
import WidgetKit

public struct SuiWidgetConfigurationIntent: AppIntent, WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Sui Widget"
    public static var description: IntentDescription = "Configure which wallet and content this widget shows."

    @Parameter(title: "Wallet", default: .primary)
    public var walletScope: WalletScopeOption

    @Parameter(title: "Refresh", default: .auto)
    public var refresh: RefreshFrequencyOption

    @Parameter(title: "Currency", default: .usd)
    public var currency: CurrencyOption

    @Parameter(title: "Variant", default: .default)
    public var variant: WidgetVariantOption

    public init() {}
}

// MARK: - Options

public enum WalletScopeOption: String, AppEnum {
    case all
    case primary

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Wallet Scope"
    public static var caseDisplayRepresentations: [WalletScopeOption: DisplayRepresentation] = [
        .all: "All wallets",
        .primary: "Primary wallet",
    ]
}

public enum RefreshFrequencyOption: String, AppEnum, CaseIterable {
    case auto
    case fifteenMinutes
    case thirtyMinutes
    case hourly

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Refresh Frequency"
    public static var caseDisplayRepresentations: [RefreshFrequencyOption: DisplayRepresentation] = [
        .auto: "Auto",
        .fifteenMinutes: "Every 15 minutes",
        .thirtyMinutes: "Every 30 minutes",
        .hourly: "Every hour",
    ]

    public var seconds: TimeInterval {
        switch self {
        case .auto, .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .hourly: return 60 * 60
        }
    }
}

public enum CurrencyOption: String, AppEnum, CaseIterable {
    case usd, sgd, eur, jpy, krw, cny

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    public static var caseDisplayRepresentations: [CurrencyOption: DisplayRepresentation] = [
        .usd: "USD",
        .sgd: "SGD",
        .eur: "EUR",
        .jpy: "JPY",
        .krw: "KRW",
        .cny: "CNY",
    ]

    public var symbol: String {
        switch self {
        case .usd: return "$"
        case .sgd: return "S$"
        case .eur: return "€"
        case .jpy: return "¥"
        case .krw: return "₩"
        case .cny: return "¥"
        }
    }
}

public enum WidgetVariantOption: String, AppEnum {
    /// The default v1 variant for each size (matches the design's picked direction).
    case `default`

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Variant"
    public static var caseDisplayRepresentations: [WidgetVariantOption: DisplayRepresentation] = [
        .default: "Default",
    ]
}
