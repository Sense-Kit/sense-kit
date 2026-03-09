// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SenseKitRuntime",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SenseKitRuntime",
            targets: ["SenseKitRuntime"]
        )
    ],
    targets: [
        .target(
            name: "SenseKitRuntime",
            path: "Sources"
        ),
        .testTarget(
            name: "SenseKitRuntimeTests",
            dependencies: ["SenseKitRuntime"],
            path: "Tests/SenseKitRuntimeTests"
        )
    ]
)
