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
(`CONNECTION_CLOSED`); fall back to the CLI below when it does. It builds the scheme
selected in Xcode only; build the other one from the CLI.

Then run `./test` with the packages you touched (`./test Presentation/Splash`): the
guard and the behavior journeys run every time.

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

The Xcode test plans run on an **iOS Simulator**. Prefer the Xcode MCP
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

### Logic tests on macOS — `./test`

The logic — `Core/Models`, `Core/CoreApp`, `Core/Analytics`, `Core/IntrospectionKit`,
`Data/*`, `Domain/*`, the migrated screens (`Presentation/Splash`, `Presentation/AppRoot`)
and `Tools/BeatRateCLI` — builds and tests on macOS with `swift test`, no simulator.
`./test` runs all of those packages, the architecture guard (no SDK or UI import in
logic), then builds `beatrate-cli` and runs the behavior journeys (`node --test
'behavior/*.test.mjs'`). Pass package paths to run just those packages, e.g.
`./test Domain/HomeUseCases`; the guard and the journeys always run. The packages share
one scratch path, `.build/logic`, because each package's own `.build` would hold its own
copy of the Firebase SDK. Legacy `Presentation/*` screens, `Core/CoreUI`, the `…UI` and
the `…Live` targets are tested with the Xcode test plan on the simulator.

```bash
./test
```

### The app without UI — `./cli` and `nc localhost 7777`

Migrated screens are Reflex view models with an introspection node: a name, the state
as JSON and the actions. `./cli` runs the app's root, `BeatRateApp(edges:)`, on fixture
files instead of the SDKs; any request without a fixture ends it with exit code 3.

```bash
printf 'ls\ndo Continue\nls\n' | ./cli behavior/fixtures/device.guest.json behavior/fixtures/catalog.discovery.json behavior/fixtures/music.undecided.json
```

The Debug app answers the same `ls` / `do <Action> {json}` on 127.0.0.1:7777, and the
UI follows (`printf 'ls\n' | nc -w 1 127.0.0.1 7777`). Release builds have no server.
Fixtures, journeys and the node rules are in the `reflex` skill
(`.claude/skills/reflex/SKILL.md`).

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

**Dependency Injection**: `Graph(edges:)` in `Domain/Composition` builds every service, repository and use case exactly once. The root, `BeatRateApp(edges:)` in `Presentation/AppRoot`, builds it and sets `Graph.current`; the iOS app passes `Edges.live()` (from `BeatRateMain.init`, before `didFinishLaunching`), the CLI `Edges.fixtures(_:)`. The only singleton left is `CrashLogger.shared`. Legacy DataModels take their default dependencies from `Graph.current`; new code receives them through `init`.

**SDK code lives in `…Live` targets**: Firebase, MusicKit and UIKit are imported only by the `…Live` targets (`AnalyticsFirebase`, `FirebaseServiceLive`, `MusicKitServiceLive`, `SpotifyServiceLive`, `CompositionLive`) and by `App/`. Every file in a `…Live` target sits inside `#if os(iOS)` and its SDK dependencies carry `condition: .when(platforms: [.iOS])`, because `swift test` builds every target of a package. `./test` fails on an SDK or UI import in logic.

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

**SwiftData Setup**: `Graph` builds the one `SwiftDataManager` from `Edges.modelContainer`, which `Edges.live()` fills with `SwiftDataManager.makeContainer()`. Views don't read it.

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

`Graph` builds the one `MusicRepository` (an actor); legacy DataModels reach it through use cases from `Graph.current`.

## Firebase Services

**AuthFirebaseService**: Apple Sign-In authentication
**DatabaseFirebaseService**: Realtime Database for storing sections and user data

Both are actors - use `await` when calling methods.

## Common Development Patterns

### Adding a New Feature Screen (Reflex)

New screens, and screens being migrated, are Reflex view models (see the `reflex` skill
and `Presentation/Splash` as the reference):

1. **A journey first** in `behavior/` against `./cli`, with the fixtures it needs.
2. **The view model** in the package's logic target `<Feature>`: `State` (Encodable,
   everything the screen shows, meanings not texts), public `Action`, internal `Message`,
   and `update(state:message:)` as the only writer of state. Copy the 10-line internal
   `ViewModel` protocol into the module. Loading starts in `init`; effects are `Task`s
   that report back with `send(message:)`. `update` never calls back into anything that
   can read this view model's state (a parent's callback, `withAnimation`) — do that
   from an effect.
3. **The node** in `<Name>ViewModel+Introspection.swift`: PascalCase actions, one per
   `Action` case, always listed; edge cases are decided in `update`, never in the node.
4. **The route**: the parent (today `AppNavigator` in `Presentation/AppRoot`) creates
   the view model — never a view, since it loads in `init`.
5. **The view** in the `<Feature>UI` target (every file in `#if os(iOS)`, iOS-only
   dependencies with `.when(platforms: [.iOS])`): reads `state`, sends actions, nothing
   else. **Build it entirely from design-system tokens** — `Spacing.*`, `Radius.*`,
   `Size.*`, `.textStyle(...)`, `.appShadow(...)`, `.roundedMaterialBackground()`,
   `.meshBackground()`, `AppAnimation.*`. See
   [Core/CoreUI/DesignSystem.md](Core/CoreUI/DesignSystem.md) for recipes.
6. **Tests of `update`** in Swift Testing: transitions and no-ops; add the package to
   `./test` and its logic `Sources` to the guard.

New packages are created by the user in Xcode; use cases and repositories as before.

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

## Unit Tests — always write them

Every code change ships with unit tests **in the module it touches**
(`<Package>/Tests/<Package>Tests/`). The goal is **100% line coverage** of each
module's non-view code (views are out of scope, see below). A change is not done until that module's tests pass and coverage is checked.

- **Before writing tests**, load the `swift-testing-expert` skill
  (`.claude/skills/swift-testing-expert`) and check whether the code is testable
  (hidden singletons, `.shared` inside logic, `Date()`/`UUID()` created inline,
  system frameworks called directly). If it isn't, make the smallest refactor that
  allows injection (protocol + init parameter with the production default) first.
- **Framework**: Swift Testing only (`import Testing`, `@Test`, `#expect`,
  `#require`). No XCTest. Group related tests in a `struct` suite named
  `<TypeUnderTest>Tests`; mark it `@MainActor` when the type under test is
  main-actor isolated (the default here, see below).
- **Test names describe the behaviour — no comment above the test.** Use Swift's
  raw identifiers (backticks) so the function name *is* the sentence:

  ```swift
  @Test func `undecodable firebase blob reads as nil without losing the album`() { ... }
  ```

  Don't add `@Test("display name")` or a `///` comment restating it. A comment is
  only for a non-obvious *why* (e.g. the bug it guards against).
- **Never unit-test SwiftUI views** (no `body`, no `ImageRenderer`, no snapshot
  tests). If a view holds logic that belongs in its view model / data model
  (state decisions, formatting, filtering, branching on data), move it there and
  test that. Don't force it: purely presentational branches (`if let image`,
  `isLoading ? … : …`) stay in the view and are simply excluded from the
  coverage target — don't create a view model just to make a line testable.
- **Reflex view models**: test `update` transitions directly (`viewModel.update(state:
  &state, message:)`), including the no-ops; test effects through stubs and by waiting
  for the view model to settle. Whole user paths belong in `behavior/` journeys.
- **Parameterize** (`@Test(arguments:)`) instead of copy-pasting tests that
  differ only by input.
- **Tests must be parallel-safe**: no shared mutable state, no real
  `UserDefaults.standard`, Keychain, network, Firebase, MusicKit or on-disk
  SwiftData. Use an in-memory `ModelContainer` or a `UserDefaults(suiteName:)`
  per test. `.serialized` only with a comment saying why.

### Test doubles — one convention for all modules

- Hand-written, no mocking libraries. Doubles live in one file per test target:
  `Tests/<Package>Tests/<Package>TestDoubles.swift`.
- Name by role + the protocol they replace:
  - `Stub<Protocol>` — returns canned / scripted values. It may record calls via
    `private(set)` properties (`sentRequests`, `saveCount`) so tests can assert
    on them. This is the default double.
  - `Fake<Protocol>` — a working lightweight implementation (in-memory store).
  - No separate `Mock`/`Spy` types; recording lives on the `Stub`.
  - The CLI's edges are `Fake…` too (`Tools/BeatRateCLI/Sources/BeatRateFixtures`),
    built from fixture files by `Edges.fixtures(_:)`.
- A double is an `actor` when the protocol is used from actors / is `Sendable`,
  otherwise a `final class` (main-actor by default isolation).
- Inject doubles through the init; never swap a `.shared` singleton in tests.
- Small fixtures (sample `AppleMusicAlbumData`, etc.) go as `static let` on the
  suite, or in the doubles file when several suites share them.
- Reference implementation: `Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyTestDoubles.swift`.

### Running a module's tests and checking coverage

Prefer the Xcode MCP (`RunSomeTests` / `RunAllTests` on the `BeatRate Development`
scheme, simulator **iPhone Duo**). For coverage from the CLI:

```bash
xcodebuild test -scheme "BeatRate Development" -project BeatRate.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -only-testing:CoreAppTests -enableCodeCoverage YES \
  -resultBundlePath /tmp/CoreApp.xcresult
```

```bash
xcrun xccov view --report --only-targets /tmp/CoreApp.xcresult
```

A logic package runs on macOS instead — its tests, then its line coverage:

```bash
./test Core/CoreApp
```

```bash
swift test --package-path Core/CoreApp --scratch-path .build/logic --enable-code-coverage && \
jq -r '.data[0].files[] | select(.filename | contains("/Sources/")) | "\(.summary.lines.percent | floor)% \(.filename)"' \
  "$(swift test --package-path Core/CoreApp --scratch-path .build/logic --show-codecov-path)"
```

Anything left uncovered must be named in the hand-back with the reason (e.g.
SwiftUI `body`, a thin wrapper over a system framework) — never silently.

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
