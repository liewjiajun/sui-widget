import Foundation
import SwiftData

public struct PriceHistoryService {
    public let modelContext: ModelContext
    public let coinGecko: CoinGeckoClient
    /// How long a cached row stays valid before re-fetch (default 1 hour).
    public let cacheTTL: TimeInterval
    public let clock: InjectableClock

    public init(
        modelContext: ModelContext,
        coinGecko: CoinGeckoClient,
        cacheTTL: TimeInterval = 60 * 60,
        clock: InjectableClock = .system
    ) {
        self.modelContext = modelContext
        self.coinGecko = coinGecko
        self.cacheTTL = cacheTTL
        self.clock = clock
    }

    /// Refreshes hourly price history for every coingeckoId that's currently
    /// in CachedCoinListEntry — i.e. every Sui-platform tracked token.
    /// Skips rows whose `fetchedAt` is within `cacheTTL`.
    /// Best-effort: per-coin failures are swallowed so one bad ID doesn't kill the batch.
    public func refreshAll() async {
        let mappings = (try? modelContext.fetch(FetchDescriptor<CachedCoinListEntry>())) ?? []
        let now = clock.now()
        for mapping in mappings {
            await refresh(coingeckoId: mapping.coingeckoId, now: now)
        }
        try? modelContext.save()
    }

    public func refresh(coingeckoId: String) async {
        await refresh(coingeckoId: coingeckoId, now: clock.now())
    }

    private func refresh(coingeckoId: String, now: Date) async {
        let descriptor = FetchDescriptor<CachedPriceHistory>(predicate: #Predicate { $0.coingeckoId == coingeckoId })
        let existing = try? modelContext.fetch(descriptor).first
        if let row = existing, now.timeIntervalSince(row.fetchedAt) < cacheTTL {
            return
        }

        do {
            // Fetch 1-day window with hourly interval = 24 points.
            let chart = try await coinGecko.fetchMarketChart(coingeckoId: coingeckoId, days: 1)
            let prices = chart.prices.map(\.price)
            if let row = existing {
                row.setPrices(prices)
                row.fetchedAt = now
            } else {
                let new = CachedPriceHistory(coingeckoId: coingeckoId, fetchedAt: now)
                new.setPrices(prices)
                modelContext.insert(new)
            }
        } catch {
            // Best-effort: keep the existing row (stale data better than nothing).
            return
        }
    }

    /// Reads the persisted hourly price points for the given coingeckoId.
    /// Returns empty array if no row exists.
    public func points(forCoingeckoId id: String) -> [Decimal] {
        let descriptor = FetchDescriptor<CachedPriceHistory>(predicate: #Predicate { $0.coingeckoId == id })
        return (try? modelContext.fetch(descriptor).first)?.prices ?? []
    }
}
