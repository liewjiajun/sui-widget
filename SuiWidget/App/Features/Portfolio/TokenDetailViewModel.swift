import Foundation
import SwiftData
import Observation
import SuiWidgetKit

@MainActor
@Observable
final class TokenDetailViewModel {
    let holding: CachedTokenHolding
    var loadState: LoadState = .idle
    var pricePoints: [CoinGeckoMarketChart.PricePoint] = []
    var sevenDayChange: Double?
    var loadError: String?

    private let modelContext: ModelContext
    private let coinGecko: CoinGeckoClient

    init(holding: CachedTokenHolding, modelContext: ModelContext) {
        self.holding = holding
        self.modelContext = modelContext
        self.coinGecko = CoinGeckoClient(modelContext: modelContext)
    }

    func load() async {
        guard holding.isTracked else {
            loadState = .empty(message: "This token isn't listed on CoinGecko.")
            return
        }

        // Look up coingecko id from cached mapping.
        let coinType = CoinTypeCanonicalizer.canonicalize(holding.coinType)
        let descriptor = FetchDescriptor<CachedCoinListEntry>(predicate: #Predicate { $0.coinType == coinType })
        guard let mapping = try? modelContext.fetch(descriptor).first else {
            loadState = .empty(message: "No CoinGecko mapping for this coin yet — pull-to-refresh Portfolio first.")
            return
        }

        loadState = .loading
        do {
            let chart = try await coinGecko.fetchMarketChart(coingeckoId: mapping.coingeckoId, days: 7)
            pricePoints = chart.prices
            sevenDayChange = computeSevenDayChange(points: chart.prices)
            loadState = pricePoints.isEmpty
                ? .empty(message: "No price history yet for this token.")
                : .loaded
        } catch {
            loadError = error.localizedDescription
            loadState = .error(message: "couldn't load chart — \(error.localizedDescription)", retry: nil)
        }
    }

    var holdingValueUSD: Decimal {
        (holding.priceUSD ?? 0) * holding.balance
    }

    var minPrice: Decimal {
        pricePoints.map(\.price).min() ?? 0
    }

    var maxPrice: Decimal {
        pricePoints.map(\.price).max() ?? 0
    }

    private func computeSevenDayChange(points: [CoinGeckoMarketChart.PricePoint]) -> Double? {
        guard let first = points.first, let last = points.last else { return nil }
        let firstDouble = (first.price as NSDecimalNumber).doubleValue
        let lastDouble = (last.price as NSDecimalNumber).doubleValue
        guard firstDouble > 0 else { return nil }
        return ((lastDouble - firstDouble) / firstDouble) * 100
    }
}
