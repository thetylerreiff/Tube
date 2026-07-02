// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tube",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TubeCore",
            targets: ["TubeCore"]
        ),
        .executable(
            name: "Tube",
            targets: ["Tube"]
        )
    ],
    targets: [
        .target(
            name: "TubeCore"
        ),
        .executableTarget(
            name: "Tube",
            dependencies: ["TubeCore"]
        ),
        .testTarget(
            name: "TubeCoreTests",
            dependencies: ["TubeCore"]
        )
    ]
)

