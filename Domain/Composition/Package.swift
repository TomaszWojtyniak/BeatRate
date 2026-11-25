// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Composition",
    platforms: [.iOS(.v27)],
    products: [
        .library(name: "Composition", targets: ["Composition"]),
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
                .product(name: "FirebaseServiceLive", package: "FirebaseService"),
                "MusicKitService",
                "SpotifyService",
                "SwiftDataManager",
                "Analytics",
                .product(name: "AnalyticsFirebase", package: "Analytics"),
                "CoreApp",
                "Models",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
    ]
)
