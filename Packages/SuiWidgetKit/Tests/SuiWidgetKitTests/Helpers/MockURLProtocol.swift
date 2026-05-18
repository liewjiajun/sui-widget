import Foundation

/// `URLProtocol` subclass that intercepts every request issued through a
/// `URLSession` configured with it. Tests register a handler that maps requests
/// to canned responses; the handler is consulted serialized on the protocol's queue.
final class MockURLProtocol: URLProtocol {
    /// (statusCode, body, optional headers). If `error` is non-nil, the protocol
    /// fails the request with that error instead of returning a response.
    typealias Stub = (statusCode: Int, data: Data, headers: [String: String], error: Error?)

    /// Handler receives the outgoing URLRequest and returns the canned response
    /// (or throws). Stored in a static so it survives across protocol instances.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Stub)?

    /// Records every URLRequest the protocol observes, in order. Useful for
    /// asserting retry behavior (e.g., "the rotator advanced after the first 429").
    nonisolated(unsafe) private(set) static var requestsObserved: [URLRequest] = []

    /// Resets handler + observed requests. Call from setUp / per-test fixtures.
    static func reset() {
        handler = nil
        requestsObserved.removeAll()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        MockURLProtocol.requestsObserved.append(request)
        do {
            let stub = try handler(request)
            if let stubError = stub.error {
                client?.urlProtocol(self, didFailWithError: stubError)
                return
            }
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "about:blank")!,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLSession {
    /// Builds a URLSession that routes every request through `MockURLProtocol`.
    /// Tests should always start with `MockURLProtocol.reset()`.
    static func mocked() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
