import Foundation
import Testing
@testable import SuiWidgetKit

extension MockURLProtocolSuite {

    @Suite("HTTPClient")
    struct HTTPClientTests {

        /// Builds a no-delay retry policy so tests don't actually sleep.
        private static let fastPolicy = HTTPClient.RetryPolicy(
            maxAttempts: 3, baseDelay: 0, jitterFactor: 0
        )

        private func makeClient() -> HTTPClient {
            HTTPClient(
                session: .mocked(),
                retryPolicy: Self.fastPolicy,
                randomJitter: { 0 }
            )
        }

        @Test func returns_2xx_response_on_first_attempt() async throws {
            MockURLProtocol.reset()
            let payload = Data("ok".utf8)
            MockURLProtocol.handler = { _ in (200, payload, [:], nil) }

            let client = makeClient()
            let request = URLRequest(url: URL(string: "https://example.com/")!)
            let (data, response) = try await client.send(request)

            #expect(response.statusCode == 200)
            #expect(data == payload)
            #expect(MockURLProtocol.requestsObserved.count == 1)
        }

        @Test func retries_on_429_then_succeeds() async throws {
            MockURLProtocol.reset()
            let queue = ResponseQueue(responses: [429, 429, 200])
            MockURLProtocol.handler = { _ in
                (queue.next(), Data("retry-body".utf8), [:], nil)
            }

            let client = makeClient()
            let (data, response) = try await client.send(URLRequest(url: URL(string: "https://example.com/")!))

            #expect(response.statusCode == 200)
            #expect(String(decoding: data, as: UTF8.self) == "retry-body")
            #expect(MockURLProtocol.requestsObserved.count == 3)
        }

        @Test func retries_on_5xx_then_succeeds() async throws {
            MockURLProtocol.reset()
            let queue = ResponseQueue(responses: [503, 200])
            MockURLProtocol.handler = { _ in (queue.next(), Data(), [:], nil) }

            let client = makeClient()
            let (_, response) = try await client.send(URLRequest(url: URL(string: "https://example.com/")!))

            #expect(response.statusCode == 200)
            #expect(MockURLProtocol.requestsObserved.count == 2)
        }

        @Test func does_not_retry_on_400() async throws {
            MockURLProtocol.reset()
            MockURLProtocol.handler = { _ in (400, Data(), [:], nil) }

            let client = makeClient()
            do {
                _ = try await client.send(URLRequest(url: URL(string: "https://example.com/")!))
                #expect(Bool(false), "expected client to throw on 400")
            } catch let error as HTTPClientError {
                #expect(error == .clientError(400))
                #expect(MockURLProtocol.requestsObserved.count == 1)
            }
        }

        @Test func exhausts_after_max_attempts_on_persistent_5xx() async throws {
            MockURLProtocol.reset()
            MockURLProtocol.handler = { _ in (503, Data(), [:], nil) }

            let client = makeClient()
            do {
                _ = try await client.send(URLRequest(url: URL(string: "https://example.com/")!))
                #expect(Bool(false), "expected exhaustion")
            } catch let error as HTTPClientError {
                if case .exhausted(let status, _) = error {
                    #expect(status == 503)
                } else {
                    #expect(Bool(false), "wrong error case: \(error)")
                }
                #expect(MockURLProtocol.requestsObserved.count == 3)
            }
        }

        @Test func retries_on_timed_out_url_error() async throws {
            MockURLProtocol.reset()
            let counter = AttemptCounter()
            MockURLProtocol.handler = { _ in
                let n = counter.increment()
                if n < 3 {
                    return (0, Data(), [:], URLError(.timedOut))
                }
                return (200, Data("ok".utf8), [:], nil)
            }

            let client = makeClient()
            let (_, response) = try await client.send(URLRequest(url: URL(string: "https://example.com/")!))
            #expect(response.statusCode == 200)
            #expect(MockURLProtocol.requestsObserved.count == 3)
        }

        @Test func does_not_retry_on_cancelled_url_error() async throws {
            MockURLProtocol.reset()
            MockURLProtocol.handler = { _ in (0, Data(), [:], URLError(.cancelled)) }

            let client = makeClient()
            do {
                _ = try await client.send(URLRequest(url: URL(string: "https://example.com/")!))
                #expect(Bool(false), "expected URLError.cancelled to propagate")
            } catch let error as URLError {
                #expect(error.code == .cancelled)
                #expect(MockURLProtocol.requestsObserved.count == 1)
            }
        }
    }
}

// MARK: - Test helpers (Swift 6 friendly mutable state for handler closures)

/// Thread-safe FIFO queue of stubbed HTTP response codes. Backed by an NSLock so
/// the handler closure (run on URLSession's background queue) can safely pop the
/// next response without triggering Swift 6 concurrency diagnostics.
final class ResponseQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [Int]
    init(responses: [Int]) { self.responses = responses }
    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        return responses.removeFirst()
    }
}

/// Monotonically increasing attempt counter used to script multi-pass test handlers.
final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int = 0
    func increment() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}
