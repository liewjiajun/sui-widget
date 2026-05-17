// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuiWidgetKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SuiWidgetKit", targets: ["SuiWidgetKit"]),
    ],
    targets: [
        .target(name: "SuiWidgetKit"),
        .testTarget(name: "SuiWidgetKitTests", dependencies: ["SuiWidgetKit"]),
    ]
)
