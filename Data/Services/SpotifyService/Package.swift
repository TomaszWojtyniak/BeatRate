// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpotifyService",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SpotifyService",
            targets: ["SpotifyService"]
        ),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Core/CoreApp")
    ],
    targets: [
        .target(
            name: "SpotifyService",
            dependencies: [
                "Models",
                "Analytics",
                "CoreApp"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "SpotifyServiceTests",
            dependencies: ["SpotifyService"]
        ),
    ]
)
