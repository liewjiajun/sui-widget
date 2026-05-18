import Foundation

public struct HTTPClient: Sendable {
    public struct RetryPolicy: Sendable {
        public var maxAttempts: Int
        public var baseDelay: TimeInterval
        public var jitterFactor: Double

        public init(
            maxAttempts: Int = 3,
            baseDelay: TimeInterval = 0.5,
            jitterFactor: Double = 0.2
        ) {
            self.maxAttempts = maxAttempts
            self.baseDelay = baseDelay
            self.jitterFactor = jitterFactor
        }

        public static let `default` = RetryPolicy()
        public static let noRetry = RetryPolicy(maxAttempts: 1, baseDelay: 0, jitterFactor: 0)
    }

    public let session: URLSession
    public let retryPolicy: RetryPolicy
    /// Random source for jitter; injectable for deterministic tests.
    private let randomJitter: @Sendable () -> Double

    public init(
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = .default,
        randomJitter: @Sendable @escaping () -> Double = { Double.random(in: -1...1) }
    ) {
        self.session = session
        self.retryPolicy = retryPolicy
        self.randomJitter = randomJitter
    }

    /// Sends the request, retrying on transient failures per `retryPolicy`.
    /// Returns `(Data, HTTPURLResponse)` on the first successful response (2xx, 3xx,
    /// or non-retryable 4xx). Throws `HTTPClientError` after exhausting attempts.
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastStatus: Int? = nil
        var lastErrorDescription: String? = nil

        for attempt in 1...retryPolicy.maxAttempts {
            if attempt > 1 {
                try await sleepForBackoff(attempt: attempt)
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw HTTPClientError.invalidResponse
                }
                lastStatus = http.statusCode

                if (200...399).contains(http.statusCode) {
                    return (data, http)
                }
                if http.statusCode == 429 || (500...599).contains(http.statusCode) {
                    // Retryable — continue loop unless this was the last attempt.
                    continue
                }
                // Non-retryable 4xx (or other non-2xx). Surface immediately.
                throw HTTPClientError.clientError(http.statusCode)
            } catch let error as HTTPClientError {
                throw error
            } catch let urlError as URLError where Self.isRetryable(urlError) {
                lastErrorDescription = "URLError.\(urlError.code.rawValue)"
                continue
            } catch {
                lastErrorDescription = String(describing: error)
                throw error
            }
        }

        throw HTTPClientError.exhausted(
            lastStatus: lastStatus,
            lastErrorDescription: lastErrorDescription
        )
    }

    private func sleepForBackoff(attempt: Int) async throws {
        // attempt index is 1-based; backoff fires before attempts 2..N.
        let exponent = attempt - 1
        let base = retryPolicy.baseDelay * pow(2.0, Double(exponent))
        let jitterMultiplier = 1.0 + retryPolicy.jitterFactor * randomJitter()
        let delay = max(0, base * jitterMultiplier)
        let nanoseconds = UInt64(delay * 1_000_000_000)
        if nanoseconds > 0 {
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    private static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet:
            return true
        case .cancelled:
            return false
        default:
            return false
        }
    }
}
