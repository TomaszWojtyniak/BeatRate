// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SearchUse",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SearchUse",
            targets: ["SearchUse"]
        ),
    ],
    dependencies: [
        .package(path: "../../Data/Repositories/MusicRepository"),
        .package(path: "../../Data/Repositories/SearchRepository"),
        .package(path: "../../Core/Models")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SearchUse",
            dependencies: [
                "MusicRepository",
                "Models",
                "SearchRepository"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "SearchUseTests",
            dependencies: ["SearchUse"]
        ),
    ]
)
