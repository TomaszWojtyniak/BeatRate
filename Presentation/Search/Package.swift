// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Search",
    defaultLocalization: "en",
    platforms: [.iOS(.v27)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Search",
            targets: ["Search"]),
    ],
    dependencies: [
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Domain/SearchUse"),
        .package(path: "../../Core/Models"),
        .package(path: "../AlbumDetails"),
        .package(path: "../ArtistDetails"),
        .package(path: "../../Core/CoreUI"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Search",
            dependencies: [
                "Analytics",
                "SearchUse",
                "Models",
                "AlbumDetails",
                "ArtistDetails",
                "CoreUI"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: ["Search"]
        ),
    ]
)
