// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MusicKitService",
    defaultLocalization: "en",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MusicKitService",
            targets: ["MusicKitService"]
        ),
        .library(
            name: "MusicKitServiceLive",
            targets: ["MusicKitServiceLive"]
        ),
    ],
    dependencies: [
        .package(path: "../../../Core/Analytics"),
        .package(path: "../../../Core/Models")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MusicKitService",
            dependencies: [
                "Models"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        // MusicKit itself, kept apart so the protocol and API helpers build and test on macOS.
        .target(
            name: "MusicKitServiceLive",
            dependencies: [
                "MusicKitService",
                "Models",
                "Analytics"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "MusicKitServiceTests",
            dependencies: ["MusicKitService"]
        ),
        .testTarget(
            name: "MusicKitServiceLiveTests",
            dependencies: ["MusicKitServiceLive"]
        ),
    ]
)
