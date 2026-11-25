// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Analytics",
    defaultLocalization: "en",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(
            name: "Analytics",
            targets: ["Analytics"]),
        .library(
            name: "AnalyticsFirebase",
            targets: ["AnalyticsFirebase"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.13.0")
    ],
    targets: [
        .target(
            name: "Analytics",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        // The Firebase backends, kept apart so the logic above builds and tests on macOS.
        .target(
            name: "AnalyticsFirebase",
            dependencies: [
                "Analytics",
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS]))
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "AnalyticsTests",
            dependencies: ["Analytics"]
        ),
    ]
)
