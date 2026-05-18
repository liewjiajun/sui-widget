import Foundation

public extension URL {
    /// If this URL is an `ipfs://CID/...` URL, returns the CID and optional path suffix.
    /// Returns nil for non-IPFS URLs.
    var ipfsComponents: (cid: String, path: String)? {
        guard scheme == "ipfs" else { return nil }
        let host = self.host ?? ""
        let trimmedPath = self.path
        return (cid: host, path: trimmedPath)
    }
}

public extension String {
    /// If this string is `ipfs://CID/...` or `https://<gateway>/ipfs/CID/...`, returns
    /// the CID + optional path suffix. Returns nil if the string is not IPFS-like.
    var ipfsComponents: (cid: String, path: String)? {
        if hasPrefix("ipfs://") {
            let stripped = String(dropFirst("ipfs://".count))
            return splitCID(from: stripped)
        }
        // gateway-prefixed: look for "/ipfs/" anywhere in the URL path
        if let range = self.range(of: "/ipfs/") {
            let after = String(self[range.upperBound...])
            return splitCID(from: after)
        }
        return nil
    }

    /// Splits "CID/path/suffix" into (cid, "/path/suffix"). Handles bare "CID" too.
    private func splitCID(from s: String) -> (cid: String, path: String) {
        if let slash = s.firstIndex(of: "/") {
            let cid = String(s[s.startIndex..<slash])
            let path = String(s[slash...])
            return (cid: cid, path: path)
        }
        return (cid: s, path: "")
    }
}
