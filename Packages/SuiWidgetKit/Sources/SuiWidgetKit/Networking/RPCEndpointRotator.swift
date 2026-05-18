import Foundation

/// Round-robin Sui RPC endpoint selector with per-endpoint failure tracking.
/// Failures within a rolling 5-minute window count against an endpoint's health;
/// once an endpoint accumulates 3 failures within the window it is marked
/// unhealthy and skipped. The window is reset lazily on the next call after
/// 5 minutes elapse since the last failure for that endpoint.
public actor RPCEndpointRotator {

    /// CLAUDE.md-locked Sui mainnet endpoints. Order is the failover preference.
    public static let mainnetEndpoints: [URL] = [
        URL(string: "https://fullnode.mainnet.sui.io:443")!,
        URL(string: "https://sui-mainnet.public.blastapi.io")!,
        URL(string: "https://sui-mainnet-rpc.allthatnode.com")!,
    ]

    /// Failures within this rolling window count against an endpoint.
    public static let resetWindow: TimeInterval = 5 * 60

    /// An endpoint with this many or more failures in the window is unhealthy.
    public static let unhealthyThreshold = 3

    public let endpoints: [URL]
    private let clock: InjectableClock
    private var failureCount: [URL: Int] = [:]
    private var lastFailureAt: [URL: Date] = [:]

    public init(
        endpoints: [URL] = RPCEndpointRotator.mainnetEndpoints,
        clock: InjectableClock = .system
    ) {
        precondition(!endpoints.isEmpty, "RPCEndpointRotator requires at least one endpoint")
        self.endpoints = endpoints
        self.clock = clock
    }

    /// Returns the first healthy endpoint in declaration order. If all endpoints
    /// are unhealthy, returns the one with the smallest current failure count
    /// (breaking ties by declaration order).
    public func currentEndpoint() -> URL {
        pruneStaleCounts()
        if let healthy = endpoints.first(where: { (failureCount[$0] ?? 0) < Self.unhealthyThreshold }) {
            return healthy
        }
        // All unhealthy — pick least-failing.
        let countsInOrder = endpoints.map { (url: $0, count: failureCount[$0] ?? 0) }
        let leastFailing = countsInOrder.min { $0.count < $1.count }!
        return leastFailing.url
    }

    public func recordFailure(at endpoint: URL) {
        pruneStaleCounts()
        failureCount[endpoint, default: 0] += 1
        lastFailureAt[endpoint] = clock.now()
    }

    public func recordSuccess(at endpoint: URL) {
        failureCount[endpoint] = 0
        lastFailureAt[endpoint] = nil
    }

    /// Test-only inspection helper.
    public func failureCount(for endpoint: URL) -> Int {
        failureCount[endpoint] ?? 0
    }

    private func pruneStaleCounts() {
        let now = clock.now()
        for (endpoint, lastFailure) in lastFailureAt {
            if now.timeIntervalSince(lastFailure) >= Self.resetWindow {
                failureCount[endpoint] = 0
                lastFailureAt[endpoint] = nil
            }
        }
    }
}
