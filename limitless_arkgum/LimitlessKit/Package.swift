// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LimitlessKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "LimitlessKit", targets: ["LimitlessKit"])
    ],
    dependencies: [
        // SQLite via GRDB. Wired in at stage 2 (storage layer).
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "LimitlessKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "LimitlessKitTests",
            dependencies: ["LimitlessKit"]
        )
    ]
)
