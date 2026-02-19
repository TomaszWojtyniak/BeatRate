// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SettingUseCases",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SettingUseCases",
            targets: ["SettingUseCases"]
        ),
    ],
    dependencies: [
        .package(path: "../../Data/Repositories/MusicRepository"),
        .package(path: "../../Domain/LoginUseCases"),
        .package(path: "../../Data/Services/SwiftDataManager"),
        .package(path: "../../Core/Models"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SettingUseCases",
            dependencies: [
                "MusicRepository",
                "LoginUseCases",
                "SwiftDataManager",
                "Models"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "SettingUseCasesTests",
            dependencies: ["SettingUseCases"]
        ),
    ]
)
