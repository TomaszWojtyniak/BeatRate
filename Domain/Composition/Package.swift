// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Composition",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        // One product, so the app still links a single library: the graph and its live edges.
        .library(name: "Composition", targets: ["Composition", "CompositionLive"]),
    ],
    dependencies: [
        .package(path: "../AccountUseCases"),
        .package(path: "../AppUseCases"),
        .package(path: "../ArtistUseCase"),
        .package(path: "../HomeUseCases"),
        .package(path: "../LoginUseCases"),
        .package(path: "../SearchUse"),
        .package(path: "../SettingUseCases"),
        .package(path: "../SplashUseCases"),
        .package(path: "../../Data/Repositories/AccountRepository"),
        .package(path: "../../Data/Repositories/HomeRepository"),
        .package(path: "../../Data/Repositories/LoginRepository"),
        .package(path: "../../Data/Repositories/MusicRepository"),
        .package(path: "../../Data/Repositories/SearchRepository"),
        .package(path: "../../Data/Services/FirebaseService"),
        .package(path: "../../Data/Services/MusicKitService"),
        .package(path: "../../Data/Services/SpotifyService"),
        .package(path: "../../Data/Services/SwiftDataManager"),
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Core/CoreApp"),
        .package(path: "../../Core/Models"),
    ],
    targets: [
        // The object graph, built only from the logic packages.
        .target(
            name: "Composition",
            dependencies: [
                "AccountUseCases",
                "AppUseCases",
                "ArtistUseCase",
                "HomeUseCases",
                "LoginUseCases",
                "SearchUse",
                "SettingUseCases",
                "SplashUseCases",
                "AccountRepository",
                "HomeRepository",
                "LoginRepository",
                "MusicRepository",
                "SearchRepository",
                "FirebaseService",
                "MusicKitService",
                "SpotifyService",
                "SwiftDataManager",
                "Analytics",
                "CoreApp",
                "Models",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        // `Edges.live()`: the SDK implementations the app plugs into the graph.
        .target(
            name: "CompositionLive",
            dependencies: [
                "Composition",
                "CoreApp",
                "SwiftDataManager",
                "SplashUseCases",
                "SpotifyService",
                "FirebaseService",
                .product(name: "FirebaseServiceLive", package: "FirebaseService", condition: .when(platforms: [.iOS])),
                .product(name: "MusicKitServiceLive", package: "MusicKitService", condition: .when(platforms: [.iOS])),
                .product(name: "SpotifyServiceLive", package: "SpotifyService", condition: .when(platforms: [.iOS])),
                .product(name: "AnalyticsFirebase", package: "Analytics", condition: .when(platforms: [.iOS])),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "CompositionTests",
            dependencies: ["Composition"]
        ),
    ]
)
