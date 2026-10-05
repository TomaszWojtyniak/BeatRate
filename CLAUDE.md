# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BeatRate is a Swift iOS music discovery app built with SwiftUI and Clean Architecture. The app integrates with Apple Music (MusicKit) and Firebase for authentication, analytics, and remote database storage. It uses Swift 6.2 with modern concurrency patterns (actors, async/await) and SwiftData for local caching.

**Platform**: iOS 27+
**Swift Version**: 6.2
**Main Branch**: `development`

## Design system — read this before touching any view

Every spacing, radius, size, font, shadow, animation, and reusable colour the
app uses is documented in **[Core/CoreUI/DesignSystem.md](Core/CoreUI/DesignSystem.md)**.
It also contains copy-paste recipes for the common view shapes (section card,
stat tile, primary CTA pill, list row, etc.) and an anti-pattern table.

When building or modifying SwiftUI views in this codebase:
- **Do not** type magic numbers into `.padding(...)`, `.frame(...)`, `cornerRadius:`,
  `lineWidth:`, `.font(.system(size:weight:))`, `.shadow(...)`, or animation duration.
- **Do** pick a token — `Spacing.lg`, `Radius.large`, `Size.thumbnailLarge`,
  `Stroke.hairline`, `.textStyle(.bodyEmphasis)`, `.appShadow(.medium)`,
  `AppAnimation.quick`, etc.
- For surfaces, use `.roundedMaterialBackground()` (Liquid Glass card) and
  `.meshBackground()` (page backdrop) instead of building card chrome by hand.
- If no existing token fits, follow the "Adding to the system" section in the
  design-system doc — don't freelance.

## Build & Run

### Verifying changes — always use the Xcode MCP

After finishing any code change, **always run the Xcode MCP `BuildProject` tool**
to verify the project builds. Do not stop work or hand back to the user until
this has succeeded. The flow is:

1. `mcp__xcode__XcodeListWorkspaces` → get the `workspaceIdentifier` for
   `BeatRate.xcodeproj` (e.g. `windowtab-9C7St5KE60`)
2. `mcp__xcode__BuildProject` with that `workspaceIdentifier`; pass
   `buildForTesting: true` when you also want the test targets compiled

Prefer the MCP over CLI `xcodebuild` — it's faster (uses the already-open Xcode
window). The MCP does sometimes fail to connect at session start
(`CONNECTION_CLOSED`); fall back to the CLI below when it does.

### Building the App

Two schemes available:
- **BeatRate**: Production scheme
- **BeatRate Development**: Development scheme

```bash
# Build production
xcodebuild -scheme "BeatRate" -project BeatRate.xcodeproj \
  -destination 'generic/platform=iOS Simulator' -quiet build

# Build development
xcodebuild -scheme "BeatRate Development" -project BeatRate.xcodeproj \
  -destination 'generic/platform=iOS Simulator' -quiet build

# Run in Xcode (recommended)
open BeatRate.xcodeproj
```

> **Note:** check the **exit code**, not the output: under `-quiet` a target whose only
> diagnostic is a warning still prints `error: the following command failed with
> exit code 0 but produced no further output`. Exit code 0 means the build
> succeeded.

### Running Tests

Tests run against an **iOS Simulator** only. Prefer the Xcode MCP
(`mcp__xcode__RunAllTests` / `mcp__xcode__RunSomeTests`, with
`mcp__xcode__GetTestList` to see what exists) for the same reasons as
`BuildProject`.

From the CLI, a simulator destination is **required** — without `-destination`,
xcodebuild picks "My Mac" and fails provisioning:

```bash
xcodebuild -scheme "BeatRate" -project BeatRate.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

That needs a simulator *device* to exist, not just a runtime. If
`xcrun simctl list devices available` is empty, create one:

```bash
xcrun simctl create "iPhone 17" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17 \
  com.apple.CoreSimulator.SimRuntime.iOS-27-0
```

> **`swift test` does not work in this repo** — don't reach for it. Two
> independent reasons:
>
> 1. `Core/Models` declares `platforms: [.iOS(.v27)]` and no macOS, so SwiftPM
>    builds it for the host at `macos12.0`, where SwiftData's `PersistentModel`
>    conformance fails to compile. This hits every package that depends on
>    Models — which is nearly all of them.
> 2. Local `.package(path:)` references under `Data/` are off by one directory
>    (`../../Core/Models` from `Data/Services/X` resolves to `Data/Core/Models`).
>    Xcode resolves these by package name and builds fine; SwiftPM resolves
>    strictly by path and fails.
>
> To run a single package's tests, use its own scheme with an iOS Simulator
> destination rather than `swift test`.

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
3. Create View + DataModel (Observable class). **Build the View entirely from
   design-system tokens** — `Spacing.*`, `Radius.*`, `Size.*`, `.textStyle(...)`,
   `.appShadow(...)`, `.roundedMaterialBackground()`, `.meshBackground()`,
   `AppAnimation.*`. See [Core/CoreUI/DesignSystem.md](Core/CoreUI/DesignSystem.md)
   for recipes (section card, stat tile, primary CTA pill, list row, etc.).
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
- **Visual work goes through the design system.** Tokens, surfaces, shadows,
  typography, animation curves — see [Core/CoreUI/DesignSystem.md](Core/CoreUI/DesignSystem.md).
  No magic numbers in views; if a token doesn't exist, follow the doc's
  "Adding to the system" guidance.

### `.defaultIsolation(MainActor.self)` and struct inits

Because every package uses `.defaultIsolation(MainActor.self)`, **all declarations in those packages are `@MainActor`-isolated by default** — including struct initializers. This means calling a struct init from a non-`@MainActor` actor (e.g., a custom `actor` like `MusicKitService` or `MusicRepository`) requires `await`, which performs a genuine actor hop to the main actor's executor.

```swift
// MusicKitService is a custom actor, not @MainActor.
// MusicAuthorizationResult.init is @MainActor-isolated due to defaultIsolation.
// The await hops to the main actor to run the init, then returns the value.
return await MusicAuthorizationResult(status: status, hasSubscription: false)
```

Do not remove these `await` keywords — they are required for correctness, not style.
