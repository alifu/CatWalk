// swift-tools-version: 6.2

import PackageDescription

/// The inspector is compiled in for Debug builds, or for any configuration when the host enables
/// the `CatWalkAlwaysOn` trait. Otherwise every public API is a no-op stub (see `CatWalk.swift`).
let inspectorSettings: [SwiftSetting] = [
    .define("CATWALK_ENABLED", .when(configuration: .debug)),
    .define("CATWALK_ENABLED", .when(traits: ["CatWalkAlwaysOn"])),
]

let bootstrapSettings: [CSetting] = [
    .define("CATWALK_ENABLED", .when(configuration: .debug)),
    .define("CATWALK_ENABLED", .when(traits: ["CatWalkAlwaysOn"])),
]

let package = Package(
    name: "CatWalk",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CatWalk",
            targets: ["CatWalk"]
        ),
    ],
    traits: [
        .trait(name: "CatWalkAlwaysOn", description: "Keep the inspector in Release builds (QA, TestFlight)."),
    ],
    targets: [
        .target(
            name: "CatWalkBootstrap",
            cSettings: bootstrapSettings
        ),
        .target(
            name: "CatWalk",
            dependencies: ["CatWalkBootstrap"],
            swiftSettings: inspectorSettings
        ),
        .testTarget(
            name: "CatWalkTests",
            dependencies: ["CatWalk"],
            swiftSettings: inspectorSettings
        ),
    ]
)
