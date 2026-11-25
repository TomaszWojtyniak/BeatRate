// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "BeatRateCLI",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        // Fixture files turned into fake edges: everything the headless host needs besides the root.
        .library(name: "BeatRateFixtures", targets: ["BeatRateFixtures"]),
    ],
    dependencies: [
        .package(path: "../../Domain/Composition"),
        .package(path: "../../Domain/SplashUseCases"),
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
            name: "BeatRateFixtures",
            dependencies: [
                .product(name: "Composition", package: "Composition"),
                "FirebaseService",
                .product(name: "FirebaseServiceFakes", package: "FirebaseService"),
                "MusicKitService",
                "SpotifyService",
                "SwiftDataManager",
                "Analytics",
                "CoreApp",
                "Models",
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "BeatRateFixturesTests",
            dependencies: ["BeatRateFixtures", "SplashUseCases"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
