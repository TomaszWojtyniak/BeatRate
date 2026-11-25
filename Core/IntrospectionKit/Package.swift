// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "IntrospectionKit",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "IntrospectionKit", targets: ["IntrospectionKit"]),
    ],
    targets: [
        // Copied from ReflexArchitecture_iOS @ befa64a, API unchanged.
        .target(
            name: "IntrospectionKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "IntrospectionKitTests",
            dependencies: ["IntrospectionKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
