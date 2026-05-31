import Foundation

/// Shared USD → fiat exchange-rate cache, readable by both the app and the
/// widget extension via App-Group `UserDefaults` (no SwiftData schema entry, so
/// no migration). Portfolio values are computed in USD (CoinGecko
/// `vs_currency=usd`); this store lets the UI present them in the user's chosen
/// display currency.
///
/// Backed by `UserDefaults`, which is documented thread-safe, so reads and
/// writes need no extra synchronization — hence a plain `@unchecked Sendable`
/// class rather than an actor (an actor would force its sync getters to be
/// `nonisolated`, which can't touch isolated state).
///
/// Safety contract: `rate(for:)` returns `1` for USD and for any currency whose
/// rate hasn't been fetched yet. Callers then format in the configured currency
/// only when a real rate exists (see `WidgetCurrencyFormatter`), so a missing
/// rate degrades to correct USD rather than a mislabeled wrong number.
public final class FXRateStore: @unchecked Sendable {
    public static let shared = FXRateStore()

    private let defaults: UserDefaults?
    private let ratesKey = "fx.usdRates"          // [code: Double]
    private let fetchedAtKey = "fx.fetchedAt"     // Date
    private let ttl: TimeInterval

    /// Currencies the app offers (mirror of `CurrencyOption`, minus USD).
    public static let supportedNonUSDCodes = ["SGD", "EUR", "JPY", "KRW", "CNY"]

    public init(
        suiteName: String = AppGroupStore.groupIdentifier,
        ttl: TimeInterval = 24 * 60 * 60
    ) {
        self.defaults = UserDefaults(suiteName: suiteName)
        self.ttl = ttl
    }

    /// USD→`code` multiplier. Returns 1 for USD or when no rate is cached.
    public func rate(for code: String) -> Decimal {
        let upper = code.uppercased()
        if upper == "USD" { return 1 }
        guard let map = defaults?.dictionary(forKey: ratesKey) as? [String: Double],
              let value = map[upper], value > 0 else {
            return 1
        }
        return Decimal(value)
    }

    /// True when we have a real (non-fallback) rate for the currency.
    public func hasRate(for code: String) -> Bool {
        let upper = code.uppercased()
        if upper == "USD" { return true }
        guard let map = defaults?.dictionary(forKey: ratesKey) as? [String: Double] else { return false }
        return (map[upper] ?? 0) > 0
    }

    /// Fetches USD→fiat rates if the cache is older than `ttl`. Best-effort: a
    /// failure leaves the prior cache (or none) intact.
    public func refreshIfStale(coinGecko: CoinGeckoClient, now: Date = Date()) async {
        if let fetchedAt = defaults?.object(forKey: fetchedAtKey) as? Date,
           now.timeIntervalSince(fetchedAt) < ttl,
           let map = defaults?.dictionary(forKey: ratesKey) as? [String: Double],
           !map.isEmpty {
            return
        }
        guard let rates = try? await coinGecko.fetchFiatRatesVsUSD(
            codes: Self.supportedNonUSDCodes
        ), !rates.isEmpty else {
            return
        }
        defaults?.set(rates, forKey: ratesKey)
        defaults?.set(now, forKey: fetchedAtKey)
    }
}
