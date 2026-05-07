// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Settings",
            targets: ["Settings"]),
    ],
    dependencies: [
        .package(path: "../../Domain/SplashUseCases"),
        .package(path: "../../Domain/SettingUseCases"),
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Core/CoreUI"),
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/CoreApp"),
        .package(path: "../Onboarding")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Settings",
            dependencies: [
                "SplashUseCases",
                "SettingUseCases",
                "Analytics",
                "CoreUI",
                "Models",
                "CoreApp",
                "Onboarding"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "SettingsTests",
            dependencies: ["Settings"]
        ),
    ]
)
