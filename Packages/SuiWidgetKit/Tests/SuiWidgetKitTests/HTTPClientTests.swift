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
            var responses: [Int] = [429, 429, 200]
            MockURLProtocol.handler = { _ in
                let status = responses.removeFirst()
                return (status, Data("retry-body".utf8), [:], nil)
            }

            let client = makeClient()
            let (data, response) = try await client.send(URLRequest(url: URL(string: "https://example.com/")!))

            #expect(response.statusCode == 200)
            #expect(String(decoding: data, as: UTF8.self) == "retry-body")
            #expect(MockURLProtocol.requestsObserved.count == 3)
        }

        @Test func retries_on_5xx_then_succeeds() async throws {
            MockURLProtocol.reset()
            var responses: [Int] = [503, 200]
            MockURLProtocol.handler = { _ in (responses.removeFirst(), Data(), [:], nil) }

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
            var attempt = 0
            MockURLProtocol.handler = { _ in
                attempt += 1
                if attempt < 3 {
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
