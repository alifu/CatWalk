// swift-tools-version: 6.2

import PackageDescription

/// The inspector is compiled in for Debug builds, or for any configuration when the host enables
/// the `CatWalkAlwaysOn` trait. Otherwise every public API is a no-op stub (see `CatWalk.swift`).
///
/// Optional traits compile a traffic source out to make the binary smaller. The public API stays
/// (the switches in `CWConfiguration` and `CatWalk.instrument` just do nothing).
let excludableSources: [(trait: String, flag: String, summary: String)] = [
    ("ExcludeMedia", "CATWALK_EXCLUDE_MEDIA", "AVPlayer media loading"),
    ("ExcludeWebSocket", "CATWALK_EXCLUDE_WEBSOCKET", "URLSessionWebSocketTask messages"),
    ("ExcludeWebView", "CATWALK_EXCLUDE_WEBVIEW", "WKWebView fetch/XHR reporting"),
    ("ExcludeBackgroundSessions", "CATWALK_EXCLUDE_BACKGROUND", "background session transfers"),
]

let inspectorSettings: [SwiftSetting] = [
    .define("CATWALK_ENABLED", .when(configuration: .debug)),
    .define("CATWALK_ENABLED", .when(traits: ["CatWalkAlwaysOn"])),
] + excludableSources.map { .define($0.flag, .when(traits: [$0.trait])) }

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
    traits: Set(
        [.trait(name: "CatWalkAlwaysOn", description: "Keep the inspector in Release builds (QA, TestFlight).")]
            + excludableSources.map { .trait(name: $0.trait, description: "Leave out \($0.summary) to shrink the binary.") }
    ),
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
