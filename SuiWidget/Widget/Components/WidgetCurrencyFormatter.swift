import Foundation
import SuiWidgetKit

/// Formats a USD-denominated value in the widget's configured display currency.
///
/// Portfolio values are computed and cached in USD. When `FXRateStore` has a
/// real USD→currency rate (refreshed daily), we convert and format in that
/// currency; otherwise we fall back to USD so the widget never shows a foreign
/// symbol on an unconverted number. This keeps the currency picker honest:
/// either correct converted values, or correct USD — never a mislabeled figure.
enum WidgetCurrencyFormatter {

    /// Whole-unit formatted string (no fraction digits) — used for token rows,
    /// the rectangular accessory, and inline accessory.
    static func compact(usdValue: Decimal, currency: CurrencyOption) -> String {
        format(usdValue: usdValue, currency: currency, fractionDigits: 0)
    }

    /// Resolves the effective (currency, convertedValue) pair, honoring the FX
    /// fallback. Returns USD when no real rate exists for `currency`.
    static func resolve(usdValue: Decimal, currency: CurrencyOption) -> (currency: CurrencyOption, value: Decimal) {
        guard currency != .usd, FXRateStore.shared.hasRate(for: currency.code) else {
            return (.usd, usdValue)
        }
        let rate = FXRateStore.shared.rate(for: currency.code)
        return (currency, usdValue * rate)
    }

    static func format(usdValue: Decimal, currency: CurrencyOption, fractionDigits: Int) -> String {
        let (effective, value) = resolve(usdValue: usdValue, currency: currency)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = effective.code
        f.currencySymbol = effective.symbol
        f.maximumFractionDigits = fractionDigits
        f.minimumFractionDigits = fractionDigits
        return f.string(from: value as NSDecimalNumber) ?? "\(effective.symbol)0"
    }
}
