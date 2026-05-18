// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuiWidgetKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SuiWidgetKit", targets: ["SuiWidgetKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2"),
    ],
    targets: [
        .target(
            name: "SuiWidgetKit",
            dependencies: [
                .product(name: "FeedKit", package: "FeedKit"),
            ]
        ),
        .testTarget(
            name: "SuiWidgetKitTests",
            dependencies: ["SuiWidgetKit"],
            resources: [.process("Fixtures")]
        ),
    ]
)
