// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Search",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Search",
            targets: ["Search"]),
    ],
    dependencies: [
        .package(path: "../../Domain/SearchUse"),
        .package(path: "../../Core/Models"),
        .package(path: "../AlbumDetails"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Search",
            dependencies: [
                "SearchUse",
                "Models",
                "AlbumDetails"
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
