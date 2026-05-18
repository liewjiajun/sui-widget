import Foundation

public enum ImagePipelineError: Error, LocalizedError, Equatable {
    case allGatewaysFailed(remoteURL: String)
    case decodeFailed
    case resizeFailed
    case writeFailed(detail: String)

    public var errorDescription: String? {
        switch self {
        case .allGatewaysFailed(let url): return "All IPFS gateways failed for: \(url)"
        case .decodeFailed: return "Failed to decode image data."
        case .resizeFailed: return "Failed to resize image."
        case .writeFailed(let detail): return "Failed to write image to cache: \(detail)"
        }
    }
}
