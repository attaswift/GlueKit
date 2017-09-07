// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "GlueKit",
    products: [
        .library(name: "GlueKit", type: .dynamic, targets: ["GlueKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/SipHash", from: "1.2.0"),
        .package(url: "https://github.com/attaswift/BTree", from: "4.1.0")
    ],
    targets: [
        .target(name: "GlueKit", dependencies: ["BTree", "SipHash"], path: "Sources"),
        .testTarget(name: "GlueKitTests", dependencies: ["GlueKit"], path: "Tests/GlueKitTests"),
        .testTarget(name: "PerformanceTests", dependencies: ["GlueKit"], path: "Tests/PerformanceTests")
    ],
    swiftLanguageVersions: [4]
)
