// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TabBar",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TabBar",
            targets: ["TabBar"]),
    ],
    dependencies: [
        .package(path: "../Home"),
        .package(path: "../Search"),
        .package(path: "../Settings")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TabBar",
            dependencies: [
                "Home",
                "Search",
                "Settings"
            ]
        ),
        .testTarget(
            name: "TabBarTests",
            dependencies: ["TabBar"]
        ),
    ]
)
