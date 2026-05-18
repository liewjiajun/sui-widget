import SwiftUI
import SafariServices

// SafariView is defined in NFTDetailView.swift; this file just re-exports an Identifiable URL wrapper
// usable from NewsView's sheet(item:) presentation.

struct NewsBrowserURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
