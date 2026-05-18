import Foundation

public enum SuiRPCError: Error, LocalizedError, Equatable {
    case allEndpointsFailed
    case rpcError(code: Int, message: String)
    case decodingFailed(detail: String)
    case invalidAddress(String)
    case missingResult

    public var errorDescription: String? {
        switch self {
        case .allEndpointsFailed: return "All Sui RPC endpoints failed."
        case .rpcError(let code, let message): return "Sui RPC error \(code): \(message)"
        case .decodingFailed(let detail): return "Failed to decode Sui RPC response: \(detail)"
        case .invalidAddress(let s): return "Invalid Sui address: \(s)"
        case .missingResult: return "Sui RPC response missing 'result' field"
        }
    }
}
