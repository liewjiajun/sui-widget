import Foundation

public struct IPFSGatewayResolver: Sendable {
    public static let gateways: [String] = [
        "https://ipfs.io/ipfs/",
        "https://cloudflare-ipfs.com/ipfs/",
        "https://dweb.link/ipfs/",
    ]

    public let gateways: [String]

    public init(gateways: [String] = IPFSGatewayResolver.gateways) {
        self.gateways = gateways
    }

    /// Given a remote URL string, returns ordered candidate URLs to try.
    /// - For `ipfs://CID/...` or `https://<some-gateway>/ipfs/CID/...`: returns
    ///   `[gateway1+CID+path, gateway2+CID+path, gateway3+CID+path]`
    /// - For non-IPFS URLs: returns `[parsedURL]` (or empty if unparseable)
    public func candidates(for urlString: String) -> [URL] {
        if let ipfs = urlString.ipfsComponents {
            return gateways.compactMap { gateway in
                URL(string: gateway + ipfs.cid + ipfs.path)
            }
        }
        if let direct = URL(string: urlString) {
            return [direct]
        }
        return []
    }
}
