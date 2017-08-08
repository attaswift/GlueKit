// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "GlueKit",
    products: [
        .library(name: "GlueKit", type: .dynamic, targets: ["GlueKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/lorentey/SipHash", .branch("swift4")),
        .package(url: "https://github.com/lorentey/BTree", .branch("5.x"))
    ],
    targets: [
        .target(name: "GlueKit", dependencies: ["BTree", "SipHash"], path: "Sources"),
        .testTarget(name: "GlueKitTests", dependencies: ["GlueKit"], path: "Tests/GlueKitTests"),
        .testTarget(name: "PerformanceTests", dependencies: ["GlueKit"], path: "Tests/PerformanceTests")
    ],
    swiftLanguageVersions: [4]
)
