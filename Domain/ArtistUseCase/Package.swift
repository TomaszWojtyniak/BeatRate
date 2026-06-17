// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArtistUseCase",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ArtistUseCase",
            targets: ["ArtistUseCase"]
        ),
    ],
    dependencies: [
        .package(path: "../../Data/Repositories/MusicRepository"),
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/Analytics")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ArtistUseCase",
            dependencies: [
                "MusicRepository",
                "Models",
                "Analytics"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "ArtistUseCaseTests",
            dependencies: ["ArtistUseCase"]
        ),
    ]
)
