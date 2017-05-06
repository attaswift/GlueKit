import PackageDescription

let package = Package(
    name: "GlueKit",
    targets: [
        // Test targets
        Target(name: "GlueKitTests", dependencies: ["GlueKit"]),
        Target(name: "PerformanceTests", dependencies: ["GlueKit"]),
    ],
    dependencies: [
        .Package(url: "https://github.com/lorentey/BTree", majorVersion: 4, minor: 0),
        .Package(url: "https://github.com/lorentey/SipHash", majorVersion: 1, minor: 1)
    ]
)
