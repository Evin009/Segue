// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SegueCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SegueCore", targets: ["SegueCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.12.0"),
    ],
    targets: [
        .target(
            name: "SegueCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(
            name: "SegueCoreTests",
            dependencies: [
                "SegueCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
