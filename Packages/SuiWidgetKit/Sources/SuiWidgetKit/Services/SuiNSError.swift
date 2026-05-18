import Foundation

public enum SuiNSError: Error, LocalizedError, Equatable {
    case invalidAddress(String)
    case invalidName(String)
    case nameNotFound(String)
    case rpc(SuiRPCError)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress(let s): return "Invalid Sui address: \(s)"
        case .invalidName(let s): return "Invalid SuiNS name: \(s)"
        case .nameNotFound(let s): return "SuiNS name not found: \(s)"
        case .rpc(let underlying): return "Sui RPC error during SuiNS resolution: \(underlying.localizedDescription)"
        }
    }
}
