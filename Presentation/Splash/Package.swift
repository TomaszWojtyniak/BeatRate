// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Splash",
    defaultLocalization: "en",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "Splash", targets: ["Splash"]),
        .library(name: "SplashUI", targets: ["SplashUI"]),
    ],
    dependencies: [
        .package(path: "../../Domain/SplashUseCases"),
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Core/CoreApp"),
        .package(path: "../../Core/CoreUI"),
        .package(path: "../../Core/IntrospectionKit"),
        .package(path: "../../Core/Models"),
        .package(path: "../Onboarding")
    ],
    targets: [
        // The launch flow as a view model: builds and tests on macOS, drives the CLI.
        .target(
            name: "Splash",
            dependencies: [
                "SplashUseCases",
                "Analytics",
                "CoreApp",
                "IntrospectionKit",
                "Models"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        // The SwiftUI views. Every file sits in `#if os(iOS)`, because `swift test` builds every target.
        .target(
            name: "SplashUI",
            dependencies: [
                "Splash",
                .product(name: "CoreUI", package: "CoreUI", condition: .when(platforms: [.iOS])),
                .product(name: "Onboarding", package: "Onboarding", condition: .when(platforms: [.iOS]))
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "SplashTests",
            dependencies: ["Splash"]
        ),
    ]
)
