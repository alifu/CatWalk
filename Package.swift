// swift-tools-version: 6.2

import PackageDescription

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
    targets: [
        .target(
            name: "CatWalk"
        ),
        .testTarget(
            name: "CatWalkTests",
            dependencies: ["CatWalk"]
        ),
    ]
)
