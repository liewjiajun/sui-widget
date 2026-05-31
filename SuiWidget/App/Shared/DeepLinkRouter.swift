import Foundation

/// Parses `suiwidget://` URLs into typed destinations the app routes to.
public enum DeepLinkDestination: Equatable {
    case wallet(UUID)
    case stakeList
    case nft(objectId: String)
    case news(itemId: String)
}

public enum DeepLinkRouter {
    /// Returns nil for unrecognized URLs.
    public static func destination(from url: URL) -> DeepLinkDestination? {
        guard url.scheme == "suiwidget" else { return nil }
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "wallet":
            guard let idString = pathComponents.first, let uuid = UUID(uuidString: idString) else { return nil }
            return .wallet(uuid)
        case "stake":
            return .stakeList
        case "nft":
            guard let id = pathComponents.first else { return nil }
            return .nft(objectId: id)
        case "news":
            guard let id = pathComponents.first else { return nil }
            return .news(itemId: id)
        default:
            return nil
        }
    }
}
