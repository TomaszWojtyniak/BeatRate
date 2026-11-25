// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FirebaseService",
    defaultLocalization: "en",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FirebaseService",
            targets: ["FirebaseService"]
        ),
        .library(
            name: "FirebaseServiceLive",
            targets: ["FirebaseServiceLive"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.13.0"),
        .package(path: "../../../Core/Analytics"),
        .package(path: "../../../Core/Models"),
        .package(path: "../../../Core/CoreApp")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FirebaseService",
            dependencies: [
                "Analytics",
                "Models",
                "CoreApp"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        // The Firebase SDK adapters, kept apart so the logic above builds and tests on macOS.
        .target(
            name: "FirebaseServiceLive",
            dependencies: [
                "FirebaseService",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS]))
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "FirebaseServiceTests",
            dependencies: ["FirebaseService"]
        ),
    ]
)
