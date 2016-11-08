import PackageDescription

let package = Package(
    name: "GlueKit",
    dependencies: [.Package(url: "https://github.com/lorentey/BTree", majorVersion: 4, minor: 0)]
)
