import Foundation
import Testing
@testable import SuiWidgetKit

@Suite("RPCEndpointRotator")
struct RPCEndpointRotatorTests {
    private static let a = URL(string: "https://a.example/")!
    private static let b = URL(string: "https://b.example/")!
    private static let c = URL(string: "https://c.example/")!

    @Test func returns_first_endpoint_when_all_healthy() async {
        let rotator = RPCEndpointRotator(endpoints: [Self.a, Self.b, Self.c])
        let endpoint = await rotator.currentEndpoint()
        #expect(endpoint == Self.a)
    }

    @Test func skips_unhealthy_endpoint_after_three_failures() async {
        let rotator = RPCEndpointRotator(endpoints: [Self.a, Self.b, Self.c])
        for _ in 0..<3 { await rotator.recordFailure(at: Self.a) }
        let endpoint = await rotator.currentEndpoint()
        #expect(endpoint == Self.b)
    }

    @Test func picks_least_failing_when_all_unhealthy() async {
        // a: 5 failures, b: 4 failures, c: 3 failures (all >= threshold).
        let rotator = RPCEndpointRotator(endpoints: [Self.a, Self.b, Self.c])
        for _ in 0..<5 { await rotator.recordFailure(at: Self.a) }
        for _ in 0..<4 { await rotator.recordFailure(at: Self.b) }
        for _ in 0..<3 { await rotator.recordFailure(at: Self.c) }
        let endpoint = await rotator.currentEndpoint()
        #expect(endpoint == Self.c)
    }

    @Test func record_success_clears_failure_count() async {
        let rotator = RPCEndpointRotator(endpoints: [Self.a, Self.b])
        for _ in 0..<3 { await rotator.recordFailure(at: Self.a) }
        await rotator.recordSuccess(at: Self.a)
        let endpoint = await rotator.currentEndpoint()
        #expect(endpoint == Self.a)
        #expect(await rotator.failureCount(for: Self.a) == 0)
    }

    @Test func resets_counts_after_five_minute_window() async {
        // Use a movable fixed clock: start at T0, record 3 failures for `a`,
        // advance past the 5-minute window, then check that `a` is healthy again.
        let storage = MutableDate(value: Date(timeIntervalSince1970: 1_000_000))
        let clock = InjectableClock(now: { storage.value })
        let rotator = RPCEndpointRotator(endpoints: [Self.a, Self.b], clock: clock)

        for _ in 0..<3 { await rotator.recordFailure(at: Self.a) }
        #expect(await rotator.currentEndpoint() == Self.b, "a should be unhealthy immediately")

        // Advance 5 minutes + 1 second.
        storage.value = storage.value.addingTimeInterval(5 * 60 + 1)
        #expect(await rotator.currentEndpoint() == Self.a, "a should be healthy again after window")
        #expect(await rotator.failureCount(for: Self.a) == 0)
    }

    @Test func record_failure_advances_currentEndpoint_to_next_healthy() async {
        let rotator = RPCEndpointRotator(endpoints: [Self.a, Self.b])
        for _ in 0..<3 { await rotator.recordFailure(at: Self.a) }
        // a is unhealthy; b is healthy.
        #expect(await rotator.currentEndpoint() == Self.b)
        // Make b unhealthy too.
        for _ in 0..<3 { await rotator.recordFailure(at: Self.b) }
        // Both unhealthy — both have 3 failures, tie broken by declaration order = a.
        #expect(await rotator.currentEndpoint() == Self.a)
    }
}

/// Mutable boxed Date so the clock closure can be advanced from the test body.
private final class MutableDate: @unchecked Sendable {
    var value: Date
    init(value: Date) { self.value = value }
}
