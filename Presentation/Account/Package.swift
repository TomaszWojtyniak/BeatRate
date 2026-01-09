// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Account",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Account",
            targets: ["Account"]
        ),
    ],
    dependencies: [
        .package(path: "../../Presentation/Settings"),
        .package(path: "../../Presentation/AlbumDetails"),
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/CoreUI"),
        .package(path: "../../Domain/LoginUseCases"),
        .package(path: "../../Domain/AccountUseCases")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Account",
            dependencies: [
                "Settings",
                "AlbumDetails",
                "Models",
                "CoreUI",
                "LoginUseCases",
                "AccountUseCases",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "AccountTests",
            dependencies: ["Account"]
        ),
    ]
)
