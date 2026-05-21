// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Onboarding",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "Onboarding",
            targets: ["Onboarding"]
        ),
    ],
    dependencies: [
        .package(path: "../../Core/Models"),
        .package(path: "../../Core/CoreApp"),
        .package(path: "../../Core/CoreUI"),
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Domain/SettingUseCases")
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: [
                "Models",
                "CoreApp",
                "CoreUI",
                "Analytics",
                "SettingUseCases"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "OnboardingTests",
            dependencies: ["Onboarding"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
