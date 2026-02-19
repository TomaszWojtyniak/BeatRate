# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BeatRate is a Swift iOS music discovery app built with SwiftUI and Clean Architecture. The app integrates with Apple Music (MusicKit) and Firebase for authentication, analytics, and remote database storage. It uses Swift 6.2 with modern concurrency patterns (actors, async/await) and SwiftData for local caching.

**Platform**: iOS 26+
**Swift Version**: 6.2
**Main Branch**: `development`

## Build & Run

### Building the App

Two schemes available:
- **BeatRate**: Production scheme
- **BeatRate Development**: Development scheme

```bash
# Build production
xcodebuild -scheme "BeatRate" -project BeatRate.xcodeproj build

# Build development
xcodebuild -scheme "BeatRate Development" -project BeatRate.xcodeproj build

# Run in Xcode (recommended)
open BeatRate.xcodeproj
```

### Running Tests

```bash
# Run all tests
xcodebuild -scheme "BeatRate" -project BeatRate.xcodeproj test

# Run specific test
xcodebuild -scheme "BeatRate" -project BeatRate.xcodeproj \
  -only-testing:BeatRateTests/TestClassName/testMethodName test

# Tests are also available in Swift packages
swift test --package-path Core/CoreApp
swift test --package-path Data/Repositories/HomeRepository
```

## Architecture

### Clean Architecture Layers

**Presentation → Domain → Data → Services**

```
App/
├── AppDelegate/          # App entry point, SwiftData setup
├── Development/          # Dev environment config + GoogleService-Info.plist
└── Production/           # Prod environment config + GoogleService-Info.plist

Presentation/             # SwiftUI Views + Observable Data Models
├── Login/                # Authentication flow
├── Home/                 # Main feed with album sections
├── AlbumDetails/         # Album rating and details
├── Search/               # Music search
├── Account/              # User account
├── Settings/             # App settings
├── Splash/               # Initial loading
└── TabBar/               # Tab navigation

Domain/                   # Business Logic (Use Cases)
├── LoginUseCases/        # GetLoginUseCase, SetLoginUseCase
├── HomeUseCases/         # GetHomeUseCase, SetHomeUseCase
├── SplashUseCases/       # App initialization logic
└── AppUseCases/          # Cross-cutting app-level logic

Data/
├── Repositories/         # Data aggregation layer (actors)
│   ├── LoginRepository/  # Auth data operations
│   ├── HomeRepository/   # Aggregates Firebase + MusicKit + Cache
│   └── MusicRepository/  # MusicKit integration
└── Services/             # External API/Database clients (actors)
    ├── FirebaseService/  # AuthFirebaseService, DatabaseFirebaseService
    ├── MusicKitService/  # Apple Music API integration
    └── SwiftDataManager/ # Local cache with 24-hour validity

Core/
├── CoreApp/              # App-wide utilities
├── CoreUI/               # Shared UI components
├── Models/               # Shared data models (HomeSection, AlbumModel, etc.)
└── Analytics/            # AnalyticsManager (Firebase), CrashLogger, OSLog extensions
```

### Key Architectural Patterns

**Actor-Based Concurrency**: All repositories and services are actors for thread-safe data access. Use `await` when calling repository/service methods.

**Dependency Injection**: Services use singleton pattern (`.shared`) with protocol-based abstractions for testability. Constructor injection is used throughout.

**Three-Tier Caching Strategy** (HomeRepository pattern):
1. SwiftData local cache (24-hour validity) - fastest
2. Firebase remote database - fallback
3. MusicKit API - last resort

All modules are Swift Packages with defined dependencies in `Package.swift` files.

### Data Flow

1. SwiftUI View → Observable Data Model (e.g., `HomeDataModel`)
2. Data Model → Use Case (e.g., `GetHomeUseCase`)
3. Use Case → Repository (e.g., `HomeRepository`)
4. Repository → Services (Firebase, MusicKit, SwiftData)
5. Services return data back up the chain

### Critical Implementation Details

**SwiftData Setup**: The `SwiftDataManager.shared` is injected as both an `@EnvironmentObject` and `.modelContainer()` in `BeatRateApp.swift:22-23`.

**Firebase Configuration**: Two separate `GoogleService-Info.plist` files exist:
- `App/Development/GoogleService-Info.plist` - for Development scheme
- `App/Production/GoogleService-Info.plist` - for Production scheme

**Logging**: Use categorized loggers from `Logger+Extension.swift`:
- `Logger.homeRepository`, `Logger.musicRepository`, `Logger.auth`, etc.
- All loggers use OSLog framework

**Error Handling**: Repositories catch and log errors but propagate them to use cases. Use cases decide how to present errors to data models/views.

## MusicKit Integration

MusicKit requires user authorization. The `MusicRepository` handles:
- Authorization requests
- Album searches and lookups
- Catalog data retrieval

Access via `MusicRepository.shared` (actor).

## Firebase Services

**AuthFirebaseService**: Apple Sign-In authentication
**DatabaseFirebaseService**: Realtime Database for storing sections and user data

Both are actors - use `await` when calling methods.

## Common Development Patterns

### Adding a New Feature Screen

1. Create new Swift Package in `Presentation/FeatureName/`
2. Add Package.swift with dependencies (usually CoreUI, Models, CoreApp)
3. Create View + DataModel (Observable class)
4. Create Use Case in `Domain/FeatureUseCases/`
5. Update Repository if new data source needed
6. Link package in main Xcode project

### Modifying Repository Logic

Repositories are in `Data/Repositories/`. They are actors, so:
- All methods must be `async`
- Internal state is isolated
- Use `await` when calling from outside

### Adding New Models

Add to `Core/Models/Sources/Models/`. Models should:
- Conform to `Sendable` if passed across actor boundaries
- Use `@MainActor` isolation if used only in UI
- Provide init methods for different data sources (Firebase, MusicKit, SwiftData)

## Git Workflow

- Main branch: `development` (use for PRs)
- Feature branches: `task/feature-name`
- Commit messages: Clear, descriptive, focus on "why"

## Important Notes

- All local packages use `.defaultIsolation(MainActor.self)` in their Package.swift
- The app uses Swift 6.2's strict concurrency checking
- SwiftData models are in `Core/Models` and must be compatible with the schema
- Album ratings are stored both locally (SwiftData) and remotely (Firebase)

### `.defaultIsolation(MainActor.self)` and struct inits

Because every package uses `.defaultIsolation(MainActor.self)`, **all declarations in those packages are `@MainActor`-isolated by default** — including struct initializers. This means calling a struct init from a non-`@MainActor` actor (e.g., a custom `actor` like `MusicKitService` or `MusicRepository`) requires `await`, which performs a genuine actor hop to the main actor's executor.

```swift
// MusicKitService is a custom actor, not @MainActor.
// MusicAuthorizationResult.init is @MainActor-isolated due to defaultIsolation.
// The await hops to the main actor to run the init, then returns the value.
return await MusicAuthorizationResult(status: status, hasSubscription: false)
```

Do not remove these `await` keywords — they are required for correctness, not style.
