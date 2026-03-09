// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SenseKitUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SenseKitUI",
            targets: ["SenseKitUI"]
        )
    ],
    dependencies: [
        .package(path: "../SenseKitRuntime")
    ],
    targets: [
        .target(
            name: "SenseKitUI",
            dependencies: [
                .product(name: "SenseKitRuntime", package: "SenseKitRuntime")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SenseKitUITests",
            dependencies: ["SenseKitUI"],
            path: "Tests/SenseKitUITests"
        )
    ]
)
