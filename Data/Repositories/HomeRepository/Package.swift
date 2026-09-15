// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HomeRepository",
    defaultLocalization: "en",
    platforms: [.iOS(.v27)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "HomeRepository",
            targets: ["HomeRepository"]
        ),
    ],
    dependencies: [
        .package(path: "../MusicRepository"),
        .package(path: "../../Services/FirebaseService"),
        .package(path: "../../Services/SwiftDataManager")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "HomeRepository",
            dependencies: [
                "MusicRepository",
                "FirebaseService",
                "SwiftDataManager"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "HomeRepositoryTests",
            dependencies: ["HomeRepository"]
        ),
    ]
)
