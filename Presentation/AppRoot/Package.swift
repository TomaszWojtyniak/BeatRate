// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "AppRoot",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        // The root of the object tree and the app's navigation, without UI: the iOS app and the CLI both build it.
        .library(name: "AppRoot", targets: ["AppRoot"]),
    ],
    dependencies: [
        .package(path: "../../Domain/AppUseCases"),
        .package(path: "../../Domain/Composition"),
        .package(path: "../../Domain/SplashUseCases"),
        .package(path: "../../Data/Services/FirebaseService"),
        .package(path: "../../Data/Services/MusicKitService"),
        .package(path: "../../Data/Services/SpotifyService"),
        .package(path: "../../Data/Services/SwiftDataManager"),
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Core/CoreApp"),
        .package(path: "../../Core/IntrospectionKit"),
        .package(path: "../../Core/Models"),
        .package(path: "../Splash"),
    ],
    targets: [
        .target(
            name: "AppRoot",
            dependencies: [
                .product(name: "Composition", package: "Composition"),
                .product(name: "Splash", package: "Splash"),
                "AppUseCases",
                "Analytics",
                "CoreApp",
                "IntrospectionKit",
                "Models",
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "AppRootTests",
            dependencies: [
                "AppRoot",
                "SplashUseCases",
                "FirebaseService",
                "MusicKitService",
                "SpotifyService",
                "SwiftDataManager",
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
