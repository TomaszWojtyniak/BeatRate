// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Home",
            targets: ["Home"])
    ],
    dependencies: [
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Core/CoreUI"),
        .package(path: "../../Core/CoreApp"),
        .package(path: "../../Core/Models"),
        .package(path: "../../Presentation/AlbumDetails"),
        .package(path: "../../Presentation/Account"),
        .package(path: "../../Domain/HomeUseCases")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Home", dependencies: [
                "Analytics",
                "CoreUI",
                "Models",
                "AlbumDetails",
                "Account",
                "HomeUseCases",
                "CoreApp"
            ]),
        .testTarget(
            name: "HomeTests",
            dependencies: ["Home"]
        ),
    ]
)
