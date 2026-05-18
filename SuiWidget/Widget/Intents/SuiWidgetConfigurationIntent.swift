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

    @Parameter(title: "Show wallet as", default: .suiNSName)
    public var walletDisplay: WalletIdentifierDisplayOption

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

/// How the wallet identifier line is rendered inside each widget. Per-instance
/// (each widget on the home screen can have its own choice via Edit Widget).
public enum WalletIdentifierDisplayOption: String, AppEnum, CaseIterable {
    /// "validator.sui" — the resolved SuiNS name. Falls back to short address.
    case suiNSName
    /// "@validator" — SuiNS name with the .sui suffix stripped, prefixed with @.
    /// Falls back to short address.
    case atName
    /// "0xe6d2…6a8" — truncated address.
    case address
    /// Render nothing — caller should omit the label line entirely.
    case hidden

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Wallet identifier"
    public static var caseDisplayRepresentations: [WalletIdentifierDisplayOption: DisplayRepresentation] = [
        .suiNSName: "SuiNS name (validator.sui)",
        .atName: "@ name (@validator)",
        .address: "Address (0xe6d2…6a8)",
        .hidden: "Hidden",
    ]
}
