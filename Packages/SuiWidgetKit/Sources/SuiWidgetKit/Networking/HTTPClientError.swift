import Foundation

public enum HTTPClientError: Error, LocalizedError, Equatable {
    case invalidResponse
    case clientError(Int)
    case exhausted(lastStatus: Int?, lastErrorDescription: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Response was not an HTTP response."
        case .clientError(let code):
            return "Non-retryable client error (\(code))."
        case .exhausted(let status, let description):
            let code = status.map { String($0) } ?? "n/a"
            let detail = description ?? "n/a"
            return "All retries exhausted (last status: \(code), last error: \(detail))."
        }
    }
}
