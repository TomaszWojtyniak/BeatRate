// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AccountRepository",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AccountRepository",
            targets: ["AccountRepository"]
        ),
    ],
    dependencies: [
        .package(path: "../../Data/Repositories/HomeRepository"),
        .package(path: "../../Data/Repositories/MusicRepository"),
        .package(path: "../../Data/Services/FirebaseService"),
        .package(path: "../../Data/Services/SwiftDataManager")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AccountRepository",
            dependencies: [
                "HomeRepository",
                "MusicRepository",
                "FirebaseService",
                "SwiftDataManager"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "AccountRepositoryTests",
            dependencies: ["AccountRepository"]
        ),
    ]
)
