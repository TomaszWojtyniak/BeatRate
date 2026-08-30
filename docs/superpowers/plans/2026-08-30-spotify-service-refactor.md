# Spotify Service Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `SpotifyService` into a session actor and a stateless client behind a stable facade, replacing the error handling that collapses five distinct failures into one `.invalid` state — the single defect behind all three reported bugs.

**Architecture:** `SpotifySession` (actor) owns the token lifecycle and nothing else. `SpotifyClient` (struct) owns endpoints and the retry policy, with an injected transport so every retry rule is testable without a network. `SpotifyService` stays an actor facade conforming to `SpotifyServiceProtocol`, so `MusicRepository` and above change only where behavior is deliberately altered. A `SpotifyFailure` taxonomy separates transient network failure from a genuinely dead session; `.transient` never mutates tokens and never prompts re-auth.

**Tech Stack:** Swift 6.2, strict concurrency, Swift Testing (`@Test` / `#expect` / `#require` — not XCTest), SPM local packages, `ASWebAuthenticationSession`, Keychain Services, OSLog.

**Spec:** `docs/superpowers/specs/2026-08-30-spotify-service-refactor-design.md`

---

## Before you start — read this

**Verification procedure — corrected during execution of Task 2.**

The original assumption here was wrong in an important way. Building the **`BeatRate Development`** scheme with `buildForTesting: true` reports BUILD SUCCEEDED **without ever compiling the test target** — its test plan has zero tests wired in. A green build on that scheme proves nothing about your tests.

Use the **per-package scheme** instead. Every local package has an auto-generated Xcode scheme with a real test plan (`SpotifyService` enumerates all 18 tests).

For each verification step:

1. `mcp__xcode__XcodeSwitchScheme` → `"SpotifyService"` (or `"Models"` for Task 12's Models tests)
2. `mcp__xcode__BuildProject` with `tabIdentifier: "windowtab-TEQdEess69"` and `buildForTesting: true`
3. Then switch to `"BeatRate Development"` and build again, to catch app-level breakage in Domain/Presentation

Run destination must be **`Any iOS Device (arm64, arm64_32, x86_64)`**. Do not use `My Mac` — the package imports UIKit in `SpotifyWebAuthSession.swift`, so the macOS build fails outright.

**Tests compile but cannot be executed right now.** `RunAllTests` reports "18 not run": the only real iOS destination, `iPhone Tomasz`, is currently disconnected and shows as incompatible. Tests must be written and kept compiling; the developer runs them from Xcode with the phone attached. **Never report a test as passing — you cannot observe that.**

**Two deliberate deviations from the spec**, both for testability, both intentional:

- `SpotifyFailure.transient` carries **no** associated `underlying: Error?`. The spec sketched one. Dropping it makes `SpotifyFailure` `Equatable`, which turns every classifier and retry test into a one-line `#expect`. The underlying error is logged at the throw site instead of carried.
- The Keychain stores the Spotify token set as **one JSON item** under a single key, not three separate string items. One item cannot half-write, and it removes the three-key dance entirely. Task 4 includes a migration from the old keys so existing users are not signed out by this change.

**Style rules for this codebase:**

- Every local package except `Models` sets `.defaultIsolation(MainActor.self)`. Types that must not be main-actor-isolated need an explicit `nonisolated`. Existing code follows this — match it.
- `Models` has **no** default isolation, so types added there need no `nonisolated`.
- Calling a struct `init` from a non-`@MainActor` actor requires `await`. Those `await`s are load-bearing. Do not remove them.
- New files carry the existing header comment format (`//  FileName.swift` / `//  ModuleName` / `//  Created by Tomasz Wojtyniak on DD/MM/YYYY.`).
- No magic numbers in views — see `Core/CoreUI/DesignSystem.md`. Task 18 touches a view.

---

## File Structure

**Create**

| Path | Responsibility |
|---|---|
| `Data/Services/SpotifyService/Sources/SpotifyService/SpotifyFailure.swift` | The failure taxonomy. Replaces `SpotifyError.swift`. |
| `.../SpotifyService/Networking/SpotifyResponseClassifier.swift` | Pure status-code → failure mapping and retry predicate. No I/O. |
| `.../SpotifyService/Networking/SpotifyTransport.swift` | Transport protocol + `URLSession` implementation. |
| `.../SpotifyService/Networking/SpotifyClient.swift` | Endpoint calls and the retry policy. |
| `.../SpotifyService/Auth/SpotifySession.swift` | Token lifecycle actor. |
| `.../SpotifyService/Models/SpotifyTokens.swift` | Token set with expiry. |
| `.../SpotifyService/Models/SpotifyConnection.swift` | `SpotifyPremiumStatus` + `SpotifyConnectionState`. |
| `Core/Models/Sources/Models/SpotifyLink.swift` | Pure `open.spotify.com` search URL builder. No API. |
| `.../Tests/SpotifyServiceTests/SpotifyResponseClassifierTests.swift` | Classifier tests. |
| `.../Tests/SpotifyServiceTests/SpotifyTokensTests.swift` | Expiry / decoding tests. |
| `.../Tests/SpotifyServiceTests/SpotifyClientTests.swift` | One test per retry-policy row. |
| `.../Tests/SpotifyServiceTests/SpotifySessionTests.swift` | Refresh, expiry, and sign-out-on-reject tests. |
| `.../Tests/SpotifyServiceTests/SpotifyTestDoubles.swift` | Stub transport + stub token store, shared by the above. |
| `Core/Models/Tests/ModelsTests/SpotifyLinkTests.swift` | URL builder tests. |

**Modify**

| Path | Change |
|---|---|
| `.../SpotifyService/SpotifyService.swift` | Becomes a thin facade over session + client. |
| `.../SpotifyService/SpotifyServiceProtocol.swift` | New connection state; drop `fetchRecentlyPlayed`, `searchAlbumId`; rename `hasAccessToken`. |
| `.../SpotifyService/Auth/SpotifyTokenStore.swift` | JSON token set + migration from the old keys. |
| `.../SpotifyService/Networking/SpotifyAPI.swift` | Delete the search endpoint and its constants. |
| `.../SpotifyService/Models/SpotifyAPIResponses.swift` | Add `expiresIn`; delete `SpotifySearchResponse`. |
| `.../SpotifyService/Auth/SpotifyWebAuthSession.swift` | Map cancellation to `.authCancelled`. |
| `Core/CoreApp/Sources/CoreApp/KeychainManager.swift` | Generic accessors, accessibility attribute, `SecItemUpdate`. |
| `Data/Repositories/MusicRepository/.../MusicRepository.swift` | Drop search + probe pass-throughs; rename token check. |
| `Data/Repositories/AccountRepository/.../AccountRepository.swift` | Distinguish "failed" from "empty". |
| `Domain/HomeUseCases/.../GetAlbumDetailsUseCase.swift` | Drop `searchSpotifyAlbumId`. |
| `Domain/SettingUseCases/.../GetSettingsUseCase.swift` | Drop `fetchRecentlyPlayed`; rename status check. |
| `Domain/SettingUseCases/.../SetSettingsUseCase.swift` | Persist premium as `nil` when unknown. |
| `Domain/SplashUseCases/.../GetSplashUseCase.swift` | New connection state; premium persistence. |
| `Presentation/Splash/.../SplashDataModel.swift` | Spotify never blocks launch; reconnect flow deleted. |
| `Presentation/Splash/.../AlertType.swift` | Delete the `spotifyReconnect` case. |
| `Presentation/Splash/.../SplashAlertButtons.swift` | Delete the reconnect branch and its closures. |
| `Presentation/Splash/.../SplashView.swift` | Drop the removed closure arguments. |
| `Presentation/AlbumDetails/.../AlbumDetailsDataModel.swift` | Search URL instead of API lookup. |
| `Presentation/Settings/.../SettingsDataModel.swift` | Surface `.notAllowlisted`. |
| `Presentation/Settings/.../SettingsView.swift` | Show the Spotify session notice. |
| `Presentation/Onboarding/.../MusicPlayerPickerDataModel.swift` | Renamed status check. |
| `.../Tests/SpotifyServiceTests/SpotifyServiceTests.swift` | Delete the search-URL test. |

**Delete**

- `Data/Services/SpotifyService/Sources/SpotifyService/SpotifyError.swift`

---

## Task 1: Pre-flight diagnostics (no code)

These may explain a large share of the reported behavior on their own. A user who authenticates but is not allowlisted receives **403 on every call**, which reproduces all three symptoms exactly.

**Files:** none.

- [ ] **Step 1: Verify the dashboard allowlist**

Open the Spotify Developer Dashboard → the BeatRate app → **Settings → User Management**. Confirm every non-owner test account appears there by Spotify account email. Development Mode allows 5 users total.

- [ ] **Step 2: Verify the redirect URI**

In the same Settings page, confirm `beatrate://spotify-callback` is registered **verbatim**. It must match `AppEnvironment.spotifyRedirectUri` exactly, including the scheme.

- [ ] **Step 3: Confirm whether `/me` still returns `product`**

Add a temporary log line in `SpotifyService.checkPremiumStatus` before decoding:

```swift
Logger.spotifyService.debug("Raw /me body: \(String(data: data, encoding: .utf8) ?? "nil")")
```

Run the app on a connected account, read the log, and record whether the `product` key is present. The February 2026 Dev Mode changes strip sensitive `/me` fields; if `product` is absent, Premium is not determinable client-side and must remain `.unknown` permanently. The design already handles this — this step only settles whether symptom 1 is fully fixable.

Remove the log line before committing.

- [ ] **Step 4: Record findings**

Note the answers in the PR description. No commit for this task.

---

## Task 2: Failure taxonomy and response classifier

**Files:**
- Create: `Data/Services/SpotifyService/Sources/SpotifyService/SpotifyFailure.swift`
- Create: `Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyResponseClassifier.swift`
- Create: `Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyResponseClassifierTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/SpotifyServiceTests/SpotifyResponseClassifierTests.swift`:

```swift
import Foundation
import Testing
@testable import SpotifyService

struct SpotifyResponseClassifierTests {

    @Test func successStatusesProduceNoFailure() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 200, retryAfter: nil) == nil)
        #expect(SpotifyResponseClassifier.failure(forStatus: 204, retryAfter: nil) == nil)
    }

    @Test func unauthorizedMapsToSessionExpired() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 401, retryAfter: nil) == .sessionExpired)
    }

    @Test func forbiddenMapsToNotAllowlisted() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 403, retryAfter: nil) == .notAllowlisted)
    }

    @Test func tooManyRequestsCarriesRetryAfter() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 429, retryAfter: 12) == .rateLimited(retryAfter: 12))
    }

    @Test func serverErrorsMapToTransient() {
        #expect(SpotifyResponseClassifier.failure(forStatus: 500, retryAfter: nil) == .transient)
        #expect(SpotifyResponseClassifier.failure(forStatus: 503, retryAfter: nil) == .transient)
    }

    @Test func retryableCoversRateLimitAndServerErrors() {
        #expect(SpotifyResponseClassifier.isRetryable(status: 429))
        #expect(SpotifyResponseClassifier.isRetryable(status: 502))
        #expect(SpotifyResponseClassifier.isRetryable(status: 503))
        #expect(!SpotifyResponseClassifier.isRetryable(status: 403))
        #expect(!SpotifyResponseClassifier.isRetryable(status: 401))
    }

    @Test func offlineTransportErrorIsTransientNotSessionLoss() {
        let offline = URLError(.notConnectedToInternet)
        #expect(SpotifyResponseClassifier.failure(forTransportError: offline) == .transient)
    }

    @Test func cancelledTransportErrorIsAuthCancelled() {
        #expect(SpotifyResponseClassifier.failure(forTransportError: URLError(.cancelled)) == .authCancelled)
    }

    @Test func retryAfterHeaderIsParsedAsSeconds() throws {
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://api.spotify.com/v1/me")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "7"]
        ))
        #expect(SpotifyResponseClassifier.retryAfterSeconds(from: response) == 7)
    }

    @Test func missingRetryAfterHeaderIsNil() throws {
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://api.spotify.com/v1/me")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        ))
        #expect(SpotifyResponseClassifier.retryAfterSeconds(from: response) == nil)
    }
}
```

- [ ] **Step 2: Verify it fails**

Run `mcp__xcode__BuildProject`. Expected: compile errors — `cannot find 'SpotifyResponseClassifier' in scope`.

- [ ] **Step 3: Create the taxonomy**

Create `Sources/SpotifyService/SpotifyFailure.swift`:

```swift
//
//  SpotifyFailure.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Every way a Spotify operation can fail, kept deliberately distinct.
///
/// The bug this type exists to prevent: collapsing "the network blipped" and
/// "this session is dead" into one error, which made callers sign the user out
/// on a dropped connection. `.transient` must never mutate stored tokens and
/// must never trigger a re-auth prompt.
public nonisolated enum SpotifyFailure: Error, LocalizedError, Sendable, Equatable {
    /// No tokens stored — the user has never connected, or was signed out.
    case noSession
    /// Spotify rejected the refresh token. Re-authorization is genuinely required.
    case sessionExpired
    /// HTTP 403. In Development Mode this means the account is not on the
    /// dashboard allowlist; it can also mean a missing OAuth scope.
    case notAllowlisted
    /// HTTP 429. Quota is shared across all Client IDs on the developer account.
    case rateLimited(retryAfter: TimeInterval?)
    /// Offline, timed out, or a 5xx. The session is fine — retry later.
    case transient
    /// The user dismissed the authorization sheet. Not an error to surface.
    case authCancelled
    /// The sheet could not start, or returned no authorization code.
    case authorizationFailed

    public var errorDescription: String? {
        switch self {
        case .noSession: "No Spotify session — connect your account to continue"
        case .sessionExpired: "Your Spotify session expired — reconnect to continue"
        case .notAllowlisted: "This Spotify account isn't enabled for BeatRate"
        case .rateLimited: "Spotify is limiting requests — try again shortly"
        case .transient: "Couldn't reach Spotify — check your connection"
        case .authCancelled: "Spotify sign-in was cancelled"
        case .authorizationFailed: "Spotify sign-in couldn't be completed"
        }
    }
}
```

- [ ] **Step 4: Create the classifier**

Create `Sources/SpotifyService/Networking/SpotifyResponseClassifier.swift`:

```swift
//
//  SpotifyResponseClassifier.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Pure mapping from an HTTP outcome to a `SpotifyFailure`. No I/O, no state —
/// so the whole retry policy can be tested without a network.
///
/// Note on 401: this maps it to `.sessionExpired`, which is only correct as a
/// *final* outcome. `SpotifyClient` refreshes and retries once before asking
/// the classifier to judge a 401.
nonisolated enum SpotifyResponseClassifier {

    static func failure(forStatus status: Int, retryAfter: TimeInterval?) -> SpotifyFailure? {
        switch status {
        case 200...299: nil
        case 401: .sessionExpired
        case 403: .notAllowlisted
        case 429: .rateLimited(retryAfter: retryAfter)
        default: .transient
        }
    }

    /// 429 and 5xx are worth another attempt. 401/403 are verdicts, not weather.
    static func isRetryable(status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    static func failure(forTransportError error: Error) -> SpotifyFailure {
        guard let urlError = error as? URLError else { return .transient }
        return urlError.code == .cancelled ? .authCancelled : .transient
    }

    static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: HTTP.Header.retryAfter) else { return nil }
        return TimeInterval(raw)
    }
}
```

- [ ] **Step 5: Add the Retry-After header constant**

In `Sources/SpotifyService/Networking/SpotifyNetworkClient.swift`, add to `enum Header`:

```swift
    enum Header {
        static let authorization = "Authorization"
        static let contentType = "Content-Type"
        static let retryAfter = "Retry-After"
    }
```

- [ ] **Step 6: Verify it builds**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED. `SpotifyError.swift` still exists and is still used — it is deleted in Task 10.

- [ ] **Step 7: Commit**

```bash
git add Data/Services/SpotifyService/Sources/SpotifyService/SpotifyFailure.swift Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyResponseClassifier.swift Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyNetworkClient.swift Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyResponseClassifierTests.swift
git commit -m "Add SpotifyFailure taxonomy and response classifier"
```

---

## Task 3: Token model with expiry

Today no expiry is stored, so the first request after each token lifetime eats a guaranteed 401 round-trip against a quota now shared across every Client ID on the account.

**Files:**
- Create: `Data/Services/SpotifyService/Sources/SpotifyService/Models/SpotifyTokens.swift`
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/Models/SpotifyAPIResponses.swift`
- Create: `Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyTokensTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/SpotifyServiceTests/SpotifyTokensTests.swift`:

```swift
import Foundation
import Testing
@testable import SpotifyService

struct SpotifyTokensTests {
    private let client = SpotifyNetworkClient()
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func tokenIsFreshWhenComfortablyBeforeExpiry() {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(600))
        #expect(tokens.isFresh(at: now))
    }

    @Test func tokenIsStaleInsideTheRefreshLeeway() {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(30))
        #expect(!tokens.isFresh(at: now))
    }

    @Test func expiredTokenIsStale() {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(-1))
        #expect(!tokens.isFresh(at: now))
    }

    @Test func responseDecodesExpiresInAndProjectsExpiry() throws {
        let json = Data(#"{"access_token": "abc", "refresh_token": "def", "expires_in": 3600}"#.utf8)
        let response: SpotifyTokenResponse = try client.decode(json)
        #expect(response.expiresIn == 3600)

        let tokens = response.tokens(issuedAt: now)
        #expect(tokens.accessToken == "abc")
        #expect(tokens.refreshToken == "def")
        #expect(tokens.expiresAt == now.addingTimeInterval(3600))
    }

    @Test func missingExpiresInFallsBackToDefaultLifetime() throws {
        let json = Data(#"{"access_token": "abc"}"#.utf8)
        let response: SpotifyTokenResponse = try client.decode(json)
        let tokens = response.tokens(issuedAt: now)
        #expect(tokens.expiresAt == now.addingTimeInterval(SpotifyTokenResponse.defaultLifetime))
    }

    @Test func tokensRoundTripThroughJSON() throws {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now)
        let restored = try SpotifyTokens.decoded(from: tokens.encoded())
        #expect(restored == tokens)
    }
}
```

- [ ] **Step 2: Verify it fails**

Run `mcp__xcode__BuildProject`. Expected: `cannot find 'SpotifyTokens' in scope`.

- [ ] **Step 3: Create the token model**

Create `Sources/SpotifyService/Models/SpotifyTokens.swift`:

```swift
//
//  SpotifyTokens.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// The stored Spotify credential set. Persisted as a single JSON Keychain item
/// so it can never be half-written.
nonisolated struct SpotifyTokens: Sendable, Equatable, Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    /// Refresh this far ahead of real expiry so an in-flight request can't
    /// straddle the boundary and eat an avoidable 401.
    static let refreshLeeway: TimeInterval = 60

    func isFresh(at now: Date = Date()) -> Bool {
        expiresAt.timeIntervalSince(now) > Self.refreshLeeway
    }

    /// Carries the previous refresh token forward when Spotify omits it —
    /// a refresh response only includes one when it rotates.
    func merging(_ response: SpotifyTokenResponse, issuedAt: Date = Date()) -> SpotifyTokens {
        SpotifyTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: issuedAt.addingTimeInterval(response.expiresIn ?? SpotifyTokenResponse.defaultLifetime)
        )
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decoded(from data: Data) throws -> SpotifyTokens {
        try JSONDecoder().decode(SpotifyTokens.self, from: data)
    }
}
```

- [ ] **Step 4: Add `expiresIn` to the token response**

In `Sources/SpotifyService/Models/SpotifyAPIResponses.swift`, replace `SpotifyTokenResponse` with:

```swift
nonisolated struct SpotifyTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: TimeInterval?

    /// Spotify access tokens are one hour unless told otherwise.
    static let defaultLifetime: TimeInterval = 3600

    func tokens(issuedAt: Date = Date()) -> SpotifyTokens {
        SpotifyTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: issuedAt.addingTimeInterval(expiresIn ?? Self.defaultLifetime)
        )
    }
}
```

- [ ] **Step 5: Verify it builds**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Data/Services/SpotifyService/Sources/SpotifyService/Models/ Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyTokensTests.swift
git commit -m "Add SpotifyTokens with expiry tracking"
```

---

## Task 4: Keychain hardening and generic accessors

`KeychainManager` currently repeats three near-identical save/load/delete triplets and never sets an accessibility attribute, so items default to `kSecAttrAccessibleWhenUnlocked` and fail any locked-device read.

**Files:**
- Modify: `Core/CoreApp/Sources/CoreApp/KeychainManager.swift`

- [ ] **Step 1: Replace the file body with generic accessors**

Replace everything from `private let service` to the end of the actor with:

```swift
    private let service = "com.beatrate.app"

    private enum Key {
        static let appleUserID = "appleUserID"
        /// The whole Spotify token set as one JSON item.
        static let spotifyTokens = "spotifyTokens"
        /// Pre-refactor keys, read once for migration then removed.
        static let legacySpotifyAccessToken = "spotifyAccessToken"
        static let legacySpotifyRefreshToken = "spotifyRefreshToken"
    }

    // MARK: - Generic Access

    /// `SecItemUpdate` first so an existing item keeps its creation metadata;
    /// delete-then-add leaves a window where the item simply doesn't exist.
    private func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insert = query.merging(attributes) { current, _ in current }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
                throw KeychainError.saveFailed
            }
            return
        }
        guard status == errSecSuccess else { throw KeychainError.saveFailed }
    }

    private func load(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { return nil }
            throw KeychainError.loadFailed
        }
        guard let data = result as? Data else { throw KeychainError.unexpectedData }
        return data
    }

    private func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }

    private func saveString(_ value: String, for key: String) throws {
        try save(Data(value.utf8), for: key)
    }

    private func loadString(_ key: String) throws -> String? {
        guard let data = try load(key) else { return nil }
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return value
    }

    // MARK: - Apple User ID

    public func saveAppleUserID(_ userID: String) throws {
        try saveString(userID, for: Key.appleUserID)
    }

    public func loadAppleUserID() throws -> String? {
        try loadString(Key.appleUserID)
    }

    public func deleteAppleUserID() throws {
        try delete(Key.appleUserID)
    }

    // MARK: - Spotify Tokens

    public func saveSpotifyTokens(_ data: Data) throws {
        try save(data, for: Key.spotifyTokens)
    }

    public func loadSpotifyTokens() throws -> Data? {
        try load(Key.spotifyTokens)
    }

    public func deleteSpotifyTokens() throws {
        try delete(Key.spotifyTokens)
        try delete(Key.legacySpotifyAccessToken)
        try delete(Key.legacySpotifyRefreshToken)
    }

    /// Reads the pre-refactor token pair so existing users aren't signed out by
    /// the move to a single JSON item. Returns nil once migration has happened.
    public func loadLegacySpotifyTokenPair() throws -> (accessToken: String, refreshToken: String?)? {
        guard let accessToken = try loadString(Key.legacySpotifyAccessToken) else { return nil }
        return (accessToken, try loadString(Key.legacySpotifyRefreshToken))
    }

    public func deleteLegacySpotifyTokens() throws {
        try delete(Key.legacySpotifyAccessToken)
        try delete(Key.legacySpotifyRefreshToken)
    }
}
```

- [ ] **Step 2: Verify it fails to build where expected**

Run `mcp__xcode__BuildProject`. Expected: errors in `SpotifyTokenStore.swift` — `loadSpotifyAccessToken` and friends no longer exist. That is correct; Task 5 fixes it.

- [ ] **Step 3: Commit**

```bash
git add Core/CoreApp/Sources/CoreApp/KeychainManager.swift
git commit -m "Harden Keychain with accessibility attribute and generic accessors"
```

---

## Task 5: Token store with migration

**Files:**
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/Auth/SpotifyTokenStore.swift`

- [ ] **Step 1: Replace the file**

```swift
//
//  SpotifyTokenStore.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation
import CoreApp

/// Reads and writes the Spotify token set. Protocol-backed so `SpotifySession`
/// can be tested without touching the Keychain.
nonisolated protocol SpotifyTokenStoring: Sendable {
    func load() async throws -> SpotifyTokens?
    func save(_ tokens: SpotifyTokens) async throws
    func clear() async throws
}

/// Keychain-backed store. Persists the token set as one JSON item.
nonisolated struct SpotifyTokenStore: SpotifyTokenStoring {
    let keychain: KeychainManager

    func load() async throws -> SpotifyTokens? {
        if let data = try await keychain.loadSpotifyTokens() {
            return try SpotifyTokens.decoded(from: data)
        }
        return try await migrateLegacyTokensIfPresent()
    }

    func save(_ tokens: SpotifyTokens) async throws {
        try await keychain.saveSpotifyTokens(tokens.encoded())
    }

    func clear() async throws {
        try await keychain.deleteSpotifyTokens()
    }

    /// Users who connected before the single-item format have a separate access
    /// and refresh token on file. Fold them into the new shape rather than
    /// signing them out — which would be an ironic way to ship this fix.
    ///
    /// The old format stored no expiry, so treat the access token as already
    /// stale: the first request refreshes it, which is correct and cheap.
    private func migrateLegacyTokensIfPresent() async throws -> SpotifyTokens? {
        guard let pair = try await keychain.loadLegacySpotifyTokenPair() else { return nil }
        let tokens = SpotifyTokens(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresAt: .distantPast
        )
        try await save(tokens)
        try await keychain.deleteLegacySpotifyTokens()
        return tokens
    }
}
```

- [ ] **Step 2: Verify**

Run `mcp__xcode__BuildProject`. Expected: errors remain only in `SpotifyService.swift`, which still calls `tokenStore.accessToken()`. Task 10 fixes it.

- [ ] **Step 3: Commit**

```bash
git add Data/Services/SpotifyService/Sources/SpotifyService/Auth/SpotifyTokenStore.swift
git commit -m "Store Spotify tokens as one Keychain item with legacy migration"
```

---

## Task 6: Transport protocol

**Files:**
- Create: `Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyTransport.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  SpotifyTransport.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// The seam that makes the retry policy testable. Production uses URLSession;
/// tests supply a stub that returns scripted responses.
nonisolated protocol SpotifyTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

nonisolated struct URLSessionTransport: SpotifyTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyFailure.transient
        }
        return (data, httpResponse)
    }
}
```

- [ ] **Step 2: Verify and commit**

Run `mcp__xcode__BuildProject`. Expected: no new errors.

```bash
git add Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyTransport.swift
git commit -m "Add SpotifyTransport seam for testable networking"
```

---

## Task 7: Test doubles

**Files:**
- Create: `Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyTestDoubles.swift`

- [ ] **Step 1: Create the doubles**

```swift
import Foundation
@testable import SpotifyService

/// Returns scripted responses in order and records what it was asked to send.
actor StubTransport: SpotifyTransport {
    struct Scripted {
        let status: Int
        let body: Data
        let headers: [String: String]

        init(status: Int, body: Data = Data("{}".utf8), headers: [String: String] = [:]) {
            self.status = status
            self.body = body
            self.headers = headers
        }
    }

    private var scripted: [Scripted]
    private var transportError: Error?
    private(set) var sentRequests: [URLRequest] = []

    init(scripted: [Scripted] = [], transportError: Error? = nil) {
        self.scripted = scripted
        self.transportError = transportError
    }

    var sentCount: Int { sentRequests.count }

    func authorizationHeaders() -> [String?] {
        sentRequests.map { $0.value(forHTTPHeaderField: "Authorization") }
    }

    nonisolated func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await record(request)
    }

    private func record(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sentRequests.append(request)
        if let transportError { throw transportError }
        guard !scripted.isEmpty else {
            fatalError("StubTransport ran out of scripted responses")
        }
        let next = scripted.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.status,
            httpVersion: nil,
            headerFields: next.headers
        )!
        return (next.body, response)
    }
}

/// In-memory token store. Records clears so tests can assert that a transient
/// failure never signs the user out.
actor StubTokenStore: SpotifyTokenStoring {
    private var tokens: SpotifyTokens?
    private(set) var clearCount = 0
    private(set) var saveCount = 0

    init(tokens: SpotifyTokens? = nil) {
        self.tokens = tokens
    }

    func load() async throws -> SpotifyTokens? { tokens }

    func save(_ tokens: SpotifyTokens) async throws {
        self.tokens = tokens
        saveCount += 1
    }

    func clear() async throws {
        tokens = nil
        clearCount += 1
    }

    func currentTokens() -> SpotifyTokens? { tokens }
}
```

- [ ] **Step 2: Verify and commit**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

```bash
git add Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyTestDoubles.swift
git commit -m "Add Spotify test doubles for transport and token store"
```

---

## Task 8: Session actor

**Files:**
- Create: `Data/Services/SpotifyService/Sources/SpotifyService/Auth/SpotifySession.swift`
- Create: `Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifySessionTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/SpotifyServiceTests/SpotifySessionTests.swift`:

```swift
import Foundation
import Testing
@testable import SpotifyService

struct SpotifySessionTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func freshTokens(_ offset: TimeInterval = 600) -> SpotifyTokens {
        SpotifyTokens(accessToken: "fresh", refreshToken: "r1", expiresAt: now.addingTimeInterval(offset))
    }

    private func refreshBody(accessToken: String, refreshToken: String? = nil) -> Data {
        var fields = ["access_token": accessToken, "expires_in": "3600"]
        if let refreshToken { fields["refresh_token"] = refreshToken }
        let pairs = fields.map { key, value in
            key == "expires_in" ? "\"\(key)\": \(value)" : "\"\(key)\": \"\(value)\""
        }
        return Data("{\(pairs.joined(separator: ","))}".utf8)
    }

    @Test func freshTokenIsReturnedWithoutHittingTheNetwork() async throws {
        let store = StubTokenStore(tokens: freshTokens())
        let transport = StubTransport()
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        let token = try await session.validAccessToken(at: now)

        #expect(token == "fresh")
        #expect(await transport.sentCount == 0)
    }

    @Test func staleTokenTriggersRefresh() async throws {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 200, body: refreshBody(accessToken: "renewed", refreshToken: "r2"))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        let token = try await session.validAccessToken(at: now)

        #expect(token == "renewed")
        #expect(await store.currentTokens()?.refreshToken == "r2")
    }

    @Test func refreshCarriesForwardRefreshTokenWhenSpotifyOmitsIt() async throws {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 200, body: refreshBody(accessToken: "renewed"))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        _ = try await session.validAccessToken(at: now)

        #expect(await store.currentTokens()?.refreshToken == "r1")
    }

    @Test func missingTokensThrowNoSession() async {
        let session = SpotifySession(
            tokenStore: StubTokenStore(tokens: nil),
            transport: StubTransport(),
            clientId: "cid"
        )

        await #expect(throws: SpotifyFailure.noSession) {
            _ = try await session.validAccessToken(at: now)
        }
    }

    @Test func rejectedRefreshExpiresSessionAndClearsStore() async {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 400, body: Data(#"{"error":"invalid_grant"}"#.utf8))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        await #expect(throws: SpotifyFailure.sessionExpired) {
            _ = try await session.validAccessToken(at: now)
        }
        #expect(await store.clearCount == 1)
    }

    @Test func offlineRefreshIsTransientAndKeepsTokens() async {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(transportError: URLError(.notConnectedToInternet))
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        await #expect(throws: SpotifyFailure.transient) {
            _ = try await session.validAccessToken(at: now)
        }
        #expect(await store.clearCount == 0)
        #expect(await store.currentTokens() != nil)
    }

    @Test func concurrentRefreshesCoalesceIntoOneNetworkCall() async throws {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 200, body: refreshBody(accessToken: "renewed", refreshToken: "r2"))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        async let first = session.validAccessToken(at: now)
        async let second = session.validAccessToken(at: now)
        async let third = session.validAccessToken(at: now)
        let tokens = try await [first, second, third]

        #expect(tokens == ["renewed", "renewed", "renewed"])
        #expect(await transport.sentCount == 1)
    }

    @Test func hasStoredSessionReflectsTheStoreWithoutNetwork() async {
        let empty = SpotifySession(tokenStore: StubTokenStore(tokens: nil), transport: StubTransport(), clientId: "cid")
        let populated = SpotifySession(tokenStore: StubTokenStore(tokens: freshTokens()), transport: StubTransport(), clientId: "cid")

        #expect(await empty.hasStoredSession() == false)
        #expect(await populated.hasStoredSession() == true)
    }
}
```

- [ ] **Step 2: Verify it fails**

Run `mcp__xcode__BuildProject`. Expected: `cannot find 'SpotifySession' in scope`.

- [ ] **Step 3: Create the session actor**

Create `Sources/SpotifyService/Auth/SpotifySession.swift`:

```swift
//
//  SpotifySession.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation
import Analytics
import OSLog

/// Owns the Spotify token lifecycle and nothing else: authorization, storage,
/// expiry, refresh. Endpoint knowledge lives in `SpotifyClient`.
actor SpotifySession {
    private let tokenStore: any SpotifyTokenStoring
    private let transport: any SpotifyTransport
    private let clientId: String
    private let redirectUri: URL?
    private let callbackScheme: String?

    /// In-flight refresh shared by concurrent callers. Spotify rotates refresh
    /// tokens, so two parallel refreshes would invalidate each other.
    private var refreshTask: Task<SpotifyTokens, Error>?

    init(
        tokenStore: any SpotifyTokenStoring,
        transport: any SpotifyTransport,
        clientId: String,
        redirectUri: URL? = nil,
        callbackScheme: String? = nil
    ) {
        self.tokenStore = tokenStore
        self.transport = transport
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.callbackScheme = callbackScheme
    }

    // MARK: - Authorization

    func authorize() async throws -> SpotifyTokens {
        guard let redirectUri, let callbackScheme else {
            throw SpotifyFailure.authorizationFailed
        }

        let pkce = PKCE()
        let webAuth = await SpotifyWebAuthSession()
        let code = try await webAuth.authorize(
            url: authorizationURL(codeChallenge: pkce.challenge, redirectUri: redirectUri),
            callbackScheme: callbackScheme
        )

        let response = try await postToken(fields: [
            (SpotifyAPI.Param.grantType, SpotifyAPI.GrantType.authorizationCode),
            (SpotifyAPI.Param.code, code),
            (SpotifyAPI.Param.redirectUri, redirectUri.absoluteString),
            (SpotifyAPI.Param.clientId, clientId),
            (SpotifyAPI.Param.codeVerifier, pkce.verifier)
        ])

        let tokens = response.tokens()
        try await tokenStore.save(tokens)
        Logger.spotifyService.info("Spotify authorization successful")
        return tokens
    }

    // MARK: - Token Access

    /// Returns a usable access token, refreshing proactively when the stored one
    /// is inside its leeway. Avoids the guaranteed 401 round-trip the old code
    /// paid on the first request after every expiry.
    func validAccessToken(at now: Date = Date()) async throws -> String {
        guard let tokens = try await loadTokens() else { throw SpotifyFailure.noSession }
        if tokens.isFresh(at: now) { return tokens.accessToken }
        return try await refresh(from: tokens, at: now).accessToken
    }

    /// Forces a refresh regardless of expiry. Used after a 401 on a token we
    /// believed was fresh.
    func refreshedAccessToken(at now: Date = Date()) async throws -> String {
        guard let tokens = try await loadTokens() else { throw SpotifyFailure.noSession }
        return try await refresh(from: tokens, at: now).accessToken
    }

    func hasStoredSession() async -> Bool {
        ((try? await tokenStore.load()) ?? nil) != nil
    }

    func signOut() async {
        refreshTask = nil
        try? await tokenStore.clear()
        Logger.spotifyService.info("Spotify session cleared")
    }

    // MARK: - Refresh

    private func loadTokens() async throws -> SpotifyTokens? {
        do {
            return try await tokenStore.load()
        } catch {
            Logger.spotifyService.error("Failed to read Spotify tokens: \(error)")
            throw SpotifyFailure.noSession
        }
    }

    /// `refreshTask` is assigned with no suspension between the nil-check and the
    /// store, so concurrent callers join the same refresh rather than racing.
    private func refresh(from tokens: SpotifyTokens, at now: Date) async throws -> SpotifyTokens {
        if let refreshTask { return try await refreshTask.value }

        let task = Task { try await performRefresh(from: tokens, at: now) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh(from tokens: SpotifyTokens, at now: Date) async throws -> SpotifyTokens {
        guard let refreshToken = tokens.refreshToken else {
            Logger.spotifyService.error("No refresh token on file — session expired")
            await signOut()
            throw SpotifyFailure.sessionExpired
        }

        let response = try await postToken(fields: [
            (SpotifyAPI.Param.grantType, SpotifyAPI.GrantType.refreshToken),
            (SpotifyAPI.Param.refreshToken, refreshToken),
            (SpotifyAPI.Param.clientId, clientId)
        ])

        let refreshed = tokens.merging(response, issuedAt: now)
        try await tokenStore.save(refreshed)
        Logger.spotifyService.info("Spotify token refresh successful")
        return refreshed
    }

    // MARK: - Token Endpoint

    /// The critical distinction: Spotify rejecting the grant kills the session,
    /// but a network failure must leave the tokens untouched. Conflating these
    /// is what signed users out whenever their connection blipped.
    private func postToken(fields: [(name: String, value: String)]) async throws -> SpotifyTokenResponse {
        var request = URLRequest(url: SpotifyAPI.token)
        request.httpMethod = HTTP.Method.post
        request.setValue(HTTP.HeaderValue.formURLEncoded, forHTTPHeaderField: HTTP.Header.contentType)
        request.httpBody = SpotifyNetworkClient.formEncode(fields)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            Logger.spotifyService.error("Spotify token request failed in transport: \(error)")
            throw SpotifyResponseClassifier.failure(forTransportError: error)
        }

        guard (200...299).contains(response.statusCode) else {
            Logger.spotifyService.error("Spotify token request rejected: \(response.statusCode)")
            if (400...499).contains(response.statusCode) {
                await signOut()
                throw SpotifyFailure.sessionExpired
            }
            throw SpotifyFailure.transient
        }

        do {
            return try SpotifyNetworkClient().decode(data)
        } catch {
            Logger.spotifyService.error("Spotify token response failed to decode: \(error)")
            throw SpotifyFailure.transient
        }
    }

    private func authorizationURL(codeChallenge: String, redirectUri: URL) -> URL {
        SpotifyAPI.authorize.appending(queryItems: [
            URLQueryItem(name: SpotifyAPI.Param.clientId, value: clientId),
            URLQueryItem(name: SpotifyAPI.Param.responseType, value: SpotifyAPI.Value.responseTypeCode),
            URLQueryItem(name: SpotifyAPI.Param.redirectUri, value: redirectUri.absoluteString),
            URLQueryItem(name: SpotifyAPI.Param.codeChallengeMethod, value: SpotifyAPI.Value.challengeMethodS256),
            URLQueryItem(name: SpotifyAPI.Param.codeChallenge, value: codeChallenge),
            URLQueryItem(name: SpotifyAPI.Param.scope, value: SpotifyAPI.scopes)
        ])
    }
}
```

- [ ] **Step 4: Make `formEncode` reachable**

In `Sources/SpotifyService/Networking/SpotifyNetworkClient.swift`, change `formEncode` from `private static` to `static`:

```swift
    /// Percent-encodes via URLComponents; `+` is valid in a URL query but means
    /// a space in form-urlencoded bodies, so it needs escaping on top.
    static func formEncode(_ fields: [(name: String, value: String)]) -> Data? {
```

- [ ] **Step 5: Verify it builds**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Data/Services/SpotifyService/Sources/SpotifyService/Auth/SpotifySession.swift Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyNetworkClient.swift Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifySessionTests.swift
git commit -m "Add SpotifySession actor owning the token lifecycle"
```

---

## Task 9: Client with retry policy

This task implements the table that stops the false logouts.

| Response | Action |
|---|---|
| 2xx | decode |
| 401 | one forced refresh, retry once; still 401 → `.sessionExpired` |
| 403 | `.notAllowlisted`, no retry |
| 429 | honor `Retry-After`, up to 2 retries, then `.rateLimited` |
| 5xx | exponential backoff, up to 2 retries, then `.transient` |
| transport error | `.transient`, no retry |

**Files:**
- Create: `Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyClient.swift`
- Create: `Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyClientTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/SpotifyServiceTests/SpotifyClientTests.swift`:

```swift
import Foundation
import Testing
@testable import SpotifyService

struct SpotifyClientTests {
    private let now = Date(timeIntervalSince1970: 3_000_000)

    private func session(_ transport: StubTransport, tokens: SpotifyTokens? = nil) -> SpotifySession {
        SpotifySession(
            tokenStore: StubTokenStore(tokens: tokens ?? SpotifyTokens(
                accessToken: "tok", refreshToken: "r1", expiresAt: .distantFuture
            )),
            transport: transport,
            clientId: "cid"
        )
    }

    private let userBody = Data(#"{"product": "premium"}"#.utf8)

    @Test func successfulRequestDecodes() async throws {
        let transport = StubTransport(scripted: [.init(status: 200, body: userBody)])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))

        #expect(user.product == "premium")
    }

    @Test func forbiddenIsNotAllowlistedAndIsNotRetried() async {
        let transport = StubTransport(scripted: [.init(status: 403)])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.notAllowlisted) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 1)
    }

    @Test func rateLimitRetriesThenGivesUpWithRetryAfter() async {
        let transport = StubTransport(scripted: [
            .init(status: 429, headers: ["Retry-After": "1"]),
            .init(status: 429, headers: ["Retry-After": "1"]),
            .init(status: 429, headers: ["Retry-After": "3"])
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.rateLimited(retryAfter: 3)) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 3)
    }

    @Test func rateLimitRecoversOnRetry() async throws {
        let transport = StubTransport(scripted: [
            .init(status: 429, headers: ["Retry-After": "1"]),
            .init(status: 200, body: userBody)
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))

        #expect(user.product == "premium")
        #expect(await transport.sentCount == 2)
    }

    @Test func serverErrorRetriesThenBecomesTransient() async {
        let transport = StubTransport(scripted: [
            .init(status: 503), .init(status: 503), .init(status: 503)
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.transient) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 3)
    }

    @Test func offlineIsTransientAndNotRetried() async {
        let transport = StubTransport(transportError: URLError(.notConnectedToInternet))
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.transient) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 1)
    }

    @Test func unauthorizedRefreshesOnceThenSucceeds() async throws {
        let refreshBody = Data(#"{"access_token": "renewed", "expires_in": 3600}"#.utf8)
        let transport = StubTransport(scripted: [
            .init(status: 401),                     // original request
            .init(status: 200, body: refreshBody),  // token refresh
            .init(status: 200, body: userBody)      // retried request
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))

        #expect(user.product == "premium")
        #expect(await transport.sentCount == 3)
        #expect(await transport.authorizationHeaders().last == "Bearer renewed")
    }

    @Test func persistentUnauthorizedEndsAsSessionExpired() async {
        let refreshBody = Data(#"{"access_token": "renewed", "expires_in": 3600}"#.utf8)
        let transport = StubTransport(scripted: [
            .init(status: 401),
            .init(status: 200, body: refreshBody),
            .init(status: 401)
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.sessionExpired) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
    }
}
```

- [ ] **Step 2: Verify it fails**

Run `mcp__xcode__BuildProject`. Expected: `cannot find 'SpotifyClient' in scope`.

- [ ] **Step 3: Create the client**

Create `Sources/SpotifyService/Networking/SpotifyClient.swift`:

```swift
//
//  SpotifyClient.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation
import Analytics
import OSLog

/// Performs authenticated Spotify requests and owns the retry policy. Holds no
/// mutable state; the token lifecycle belongs to `SpotifySession`.
nonisolated struct SpotifyClient: Sendable {

    /// Attempts *after* the first try, for retryable statuses only.
    static let maxRetries = 2
    /// Base for exponential backoff when the response carries no Retry-After.
    static let baseBackoff: TimeInterval = 0.5

    private let transport: any SpotifyTransport
    private let decoder = SpotifyNetworkClient()
    /// Injected so tests don't actually sleep.
    private let retryDelay: @Sendable (TimeInterval) async -> Void

    init(
        transport: any SpotifyTransport = URLSessionTransport(),
        retryDelay: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.transport = transport
        self.retryDelay = retryDelay
    }

    func get<T: Decodable>(_ url: URL, session: SpotifySession) async throws -> T {
        let data = try await data(from: url, session: session)
        do {
            return try decoder.decode(data)
        } catch {
            Logger.spotifyService.error("Spotify response failed to decode: \(error)")
            throw SpotifyFailure.transient
        }
    }

    func data(from url: URL, session: SpotifySession) async throws -> Data {
        var accessToken = try await session.validAccessToken()
        var hasRefreshed = false
        var attempt = 0

        while true {
            let outcome = try await attemptRequest(url, accessToken: accessToken)

            switch outcome {
            case .success(let data):
                return data

            case .unauthorized:
                // One forced refresh — the stored token looked fresh but Spotify
                // disagrees (revoked access, rotated secret, clock skew).
                guard !hasRefreshed else {
                    Logger.spotifyService.error("Spotify still unauthorized after refresh — session expired")
                    await session.signOut()
                    throw SpotifyFailure.sessionExpired
                }
                hasRefreshed = true
                accessToken = try await session.refreshedAccessToken()

            case .retryable(let status, let retryAfter):
                guard attempt < Self.maxRetries else {
                    let failure = SpotifyResponseClassifier.failure(forStatus: status, retryAfter: retryAfter)
                        ?? SpotifyFailure.transient
                    Logger.spotifyService.error("Spotify request exhausted retries at \(status): \(url.path())")
                    throw failure
                }
                await retryDelay(retryAfter ?? Self.baseBackoff * pow(2, Double(attempt)))
                attempt += 1

            case .failed(let failure):
                throw failure
            }
        }
    }

    // MARK: - Single Attempt

    private enum Outcome {
        case success(Data)
        case unauthorized
        case retryable(status: Int, retryAfter: TimeInterval?)
        case failed(SpotifyFailure)
    }

    private func attemptRequest(_ url: URL, accessToken: String) async throws -> Outcome {
        var request = URLRequest(url: url)
        request.setValue(
            HTTP.HeaderValue.bearerPrefix + accessToken,
            forHTTPHeaderField: HTTP.Header.authorization
        )

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            // Offline or timed out. The session is fine — never sign out here.
            Logger.spotifyService.error("Spotify transport error for \(url.path()): \(error)")
            return .failed(SpotifyResponseClassifier.failure(forTransportError: error))
        }

        let status = response.statusCode
        if (200...299).contains(status) { return .success(data) }
        if status == HTTP.Status.unauthorized { return .unauthorized }
        if SpotifyResponseClassifier.isRetryable(status: status) {
            return .retryable(status: status, retryAfter: SpotifyResponseClassifier.retryAfterSeconds(from: response))
        }
        let failure = SpotifyResponseClassifier.failure(forStatus: status, retryAfter: nil) ?? .transient
        Logger.spotifyService.error("Spotify request failed with \(status): \(url.path())")
        return .failed(failure)
    }
}
```

- [ ] **Step 4: Verify it builds**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyClient.swift Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyClientTests.swift
git commit -m "Add SpotifyClient with retry policy separating transient from fatal"
```

---

## Task 10: Connection state, premium, and the facade

**Files:**
- Create: `Data/Services/SpotifyService/Sources/SpotifyService/Models/SpotifyConnection.swift`
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/SpotifyServiceProtocol.swift`
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/SpotifyService.swift`
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/Models/SpotifyAuthResult.swift`
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/Auth/SpotifyWebAuthSession.swift`
- Delete: `Data/Services/SpotifyService/Sources/SpotifyService/SpotifyError.swift`

- [ ] **Step 1: Create the connection types**

Create `Sources/SpotifyService/Models/SpotifyConnection.swift`:

```swift
//
//  SpotifyConnection.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Three-state on purpose. A failed check is `.unknown`, never `.free` —
/// reporting "not premium" because the network blipped is the bug this replaces.
public nonisolated enum SpotifyPremiumStatus: Sendable, Equatable {
    case premium
    case free
    case unknown

    /// `nil` for `.unknown` so an unknown value is never persisted as "false".
    public var isPremium: Bool? {
        switch self {
        case .premium: true
        case .free: false
        case .unknown: nil
        }
    }

    init(product: String?) {
        switch product {
        case SpotifyAPI.Value.premiumProduct: self = .premium
        case .some: self = .free
        case .none: self = .unknown
        }
    }
}

public nonisolated enum SpotifyConnectionState: Sendable, Equatable {
    /// A valid token is on file, verified against `/me`.
    case connected(premium: SpotifyPremiumStatus)
    /// No token stored — the user has never connected.
    case notConnected
    /// Spotify rejected the session and refresh failed. Re-auth required.
    case needsReauth
    /// Transient failure. The session may be perfectly fine — never prompt.
    case unavailable
    /// HTTP 403. In Development Mode, the account is not on the allowlist.
    case notAllowlisted

    /// Whether this state warrants asking the user to reconnect. Only a genuinely
    /// dead session qualifies.
    public var requiresUserAction: Bool {
        switch self {
        case .needsReauth: true
        case .connected, .notConnected, .unavailable, .notAllowlisted: false
        }
    }
}
```

- [ ] **Step 2: Update the protocol**

Replace `Sources/SpotifyService/SpotifyServiceProtocol.swift` with:

```swift
//
//  SpotifyServiceProtocol.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

public protocol SpotifyServiceProtocol: Sendable {
    func requestAuthorization() async throws -> SpotifyAuthResult
    func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum]
    func hasStoredSession() async -> Bool
    func verifyConnection() async -> SpotifyConnectionState
}
```

- [ ] **Step 3: Update the auth result to carry premium status**

Replace `Sources/SpotifyService/Models/SpotifyAuthResult.swift` with:

```swift
//
//  SpotifyAuthResult.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 04/03/2026.
//

import Foundation

public nonisolated struct SpotifyAuthResult: Sendable {
    public let isAuthorized: Bool
    public let premium: SpotifyPremiumStatus

    public init(isAuthorized: Bool, premium: SpotifyPremiumStatus) {
        self.isAuthorized = isAuthorized
        self.premium = premium
    }
}
```

- [ ] **Step 4: Map sheet cancellation to `.authCancelled`**

In `Sources/SpotifyService/Auth/SpotifyWebAuthSession.swift`, replace `authorizationCode(from:error:)` with:

```swift
    private nonisolated static func authorizationCode(
        from callbackURL: URL?,
        error: Error?
    ) -> Result<String, Error> {
        if let error {
            // Dismissing the sheet is a choice, not a failure — callers must not
            // surface it as an error.
            let isCancellation = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            return .failure(isCancellation ? SpotifyFailure.authCancelled : SpotifyFailure.authorizationFailed)
        }
        guard let callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == SpotifyAPI.Param.code })?.value else {
            return .failure(SpotifyFailure.authorizationFailed)
        }
        return .success(code)
    }
```

And in the same file, change the `start()` guard:

```swift
            guard session.start() else {
                continuation.resume(throwing: SpotifyFailure.authorizationFailed)
                return
            }
```

- [ ] **Step 5: Rewrite the facade**

Replace `Sources/SpotifyService/SpotifyService.swift` with:

```swift
//
//  SpotifyService.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 04/03/2026.
//

import Foundation
import CoreApp
import Analytics
import OSLog

/// Facade over `SpotifySession` (tokens) and `SpotifyClient` (endpoints).
/// Callers above this layer see one small surface and never touch either.
public actor SpotifyService: SpotifyServiceProtocol {
    public static let shared = SpotifyService()

    private let session: SpotifySession
    private let client: SpotifyClient

    public init(
        clientId: String = AppEnvironment.current.spotifyClientId,
        redirectUri: String = AppEnvironment.current.spotifyRedirectUri,
        keychainManager: KeychainManager = .shared
    ) {
        guard let url = URL(string: redirectUri), let scheme = url.scheme else {
            preconditionFailure("Invalid Spotify redirect URI: \(redirectUri)")
        }
        let transport = URLSessionTransport()
        self.session = SpotifySession(
            tokenStore: SpotifyTokenStore(keychain: keychainManager),
            transport: transport,
            clientId: clientId,
            redirectUri: url,
            callbackScheme: scheme
        )
        self.client = SpotifyClient(transport: transport)
    }

    /// Test/preview seam.
    init(session: SpotifySession, client: SpotifyClient) {
        self.session = session
        self.client = client
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws -> SpotifyAuthResult {
        Logger.spotifyService.info("Starting Spotify authorization")
        _ = try await session.authorize()

        // Premium comes from the same /me call the connection check uses, so
        // connecting costs one request rather than two.
        let premium = await currentPremiumStatus()
        Logger.spotifyService.info("Spotify authorized, premium: \(String(describing: premium))")
        return await SpotifyAuthResult(isAuthorized: true, premium: premium)
    }

    // MARK: - Connection State

    public func hasStoredSession() async -> Bool {
        await session.hasStoredSession()
    }

    /// Pings `/me` and reports what actually happened. The old implementation
    /// collapsed every error into "invalid", so a dropped connection at launch
    /// forced a full reconnect.
    public func verifyConnection() async -> SpotifyConnectionState {
        do {
            let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session)
            return .connected(premium: await SpotifyPremiumStatus(product: user.product))
        } catch SpotifyFailure.noSession {
            return .notConnected
        } catch SpotifyFailure.sessionExpired {
            return .needsReauth
        } catch SpotifyFailure.notAllowlisted {
            Logger.spotifyService.error("Spotify account is not on the Development Mode allowlist")
            return .notAllowlisted
        } catch {
            // Transient, rate-limited, or unrecognized: the session is probably
            // fine. Do not prompt the user to reconnect.
            Logger.spotifyService.error("Spotify connection check unavailable: \(error)")
            return .unavailable
        }
    }

    // MARK: - Recently Played

    public func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum] {
        let response: SpotifyRecentlyPlayedResponse = try await client.get(
            SpotifyAPI.recentlyPlayed(limit: SpotifyAPI.Limit.recentlyPlayedPage),
            session: session
        )
        let albums = response.uniqueAlbums
        Logger.spotifyService.info("Resolved \(albums.count) recently-played Spotify albums")
        return albums
    }

    // MARK: - Premium

    private func currentPremiumStatus() async -> SpotifyPremiumStatus {
        do {
            let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session)
            return await SpotifyPremiumStatus(product: user.product)
        } catch {
            // Unknown, never "free" — a failed check must not read as a downgrade.
            Logger.spotifyService.error("Spotify premium check failed: \(error)")
            return .unknown
        }
    }
}
```

- [ ] **Step 6: Delete the old error type**

```bash
git rm Data/Services/SpotifyService/Sources/SpotifyService/SpotifyError.swift
```

- [ ] **Step 7: Verify**

Run `mcp__xcode__BuildProject`. Expected: errors only in `MusicRepository.swift` (still calls `hasAccessToken`, `fetchRecentlyPlayed`, `searchAlbumId`, reads `hasSpotifyPremium`). Tasks 11–14 fix those.

- [ ] **Step 8: Commit**

```bash
git add -A Data/Services/SpotifyService/Sources/SpotifyService/
git commit -m "Rewrite SpotifyService as a facade over session and client"
```

---

## Task 11: Delete the album search path

The search endpoint only ever worked for allowlisted users. Task 12 replaces it with a URL builder that works for everyone.

**Files:**
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/Networking/SpotifyAPI.swift`
- Modify: `Data/Services/SpotifyService/Sources/SpotifyService/Models/SpotifyAPIResponses.swift`
- Modify: `Data/Services/SpotifyService/Tests/SpotifyServiceTests/SpotifyServiceTests.swift`
- Modify: `Data/Repositories/MusicRepository/Sources/MusicRepository/MusicRepository.swift`
- Modify: `Domain/HomeUseCases/Sources/HomeUseCases/AlbumDetailsUseCases/GetAlbumDetailsUseCase.swift`

- [ ] **Step 1: Remove the endpoint and its constants**

In `SpotifyAPI.swift`, delete the entire `searchAlbum(name:artist:)` function including its doc comment, delete `static let query = "q"` and `static let type = "type"` from `enum Param`, delete `static let searchTypeAlbum = "album"` from `enum Value`, and delete `static let search = 1` from `enum Limit` along with its comment.

- [ ] **Step 2: Remove the response type**

In `SpotifyAPIResponses.swift`, delete the whole `SpotifySearchResponse` struct including its nested `AlbumsPage` and `AlbumItem`.

- [ ] **Step 3: Delete the search URL test**

In `Tests/SpotifyServiceTests/SpotifyServiceTests.swift`, delete the `searchAlbumURLQuotesFieldsAndStripsEmbeddedQuotes` test. Keep `recentlyPlayedURLCarriesLimit` and the enclosing `SpotifyAPITests` struct.

- [ ] **Step 4: Remove the repository pass-through**

In `MusicRepository.swift`, delete `func searchSpotifyAlbumId(name:artist:) async -> String?` from `MusicRepositoryProtocol` and delete its implementation at the bottom of the actor.

- [ ] **Step 5: Remove the use case pass-through**

In `GetAlbumDetailsUseCase.swift`, delete `func searchSpotifyAlbumId(name:artist:) async -> String?` from the protocol and its implementation.

- [ ] **Step 6: Verify**

Run `mcp__xcode__BuildProject`. Expected: one error in `AlbumDetailsDataModel.swift:79` — its only caller. Task 12 fixes it.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Delete Spotify album search endpoint and its pass-throughs"
```

---

## Task 12: Search-URL deep links

**Files:**
- Create: `Core/Models/Sources/Models/SpotifyLink.swift`
- Create: `Core/Models/Tests/ModelsTests/SpotifyLinkTests.swift`
- Modify: `Presentation/AlbumDetails/Sources/AlbumDetails/AlbumDetailsView/AlbumDetailsDataModel.swift`

Note: the `Models` package has **no** default isolation, so no `nonisolated` annotations are needed here.

- [ ] **Step 1: Write the failing test**

Create `Core/Models/Tests/ModelsTests/SpotifyLinkTests.swift`:

```swift
import Foundation
import Testing
@testable import Models

struct SpotifyLinkTests {

    @Test func buildsSearchURLFromTitleAndArtist() throws {
        let url = try #require(SpotifyLink.search(title: "Blonde", artist: "Frank Ocean"))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde%20Frank%20Ocean")
    }

    @Test func percentEncodesReservedCharacters() throws {
        let url = try #require(SpotifyLink.search(title: "Sgt. Pepper's", artist: "The Beatles"))
        #expect(url.absoluteString.contains("Sgt."))
        #expect(!url.absoluteString.contains(" "))
    }

    @Test func trimsSurroundingWhitespace() throws {
        let url = try #require(SpotifyLink.search(title: "  Blonde  ", artist: " Frank Ocean "))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde%20Frank%20Ocean")
    }

    @Test func emptyTitleAndArtistYieldsNil() {
        #expect(SpotifyLink.search(title: "   ", artist: "") == nil)
    }

    @Test func titleAloneIsEnough() throws {
        let url = try #require(SpotifyLink.search(title: "Blonde", artist: ""))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde")
    }
}
```

- [ ] **Step 2: Verify it fails**

Run `mcp__xcode__BuildProject`. Expected: `cannot find 'SpotifyLink' in scope`.

- [ ] **Step 3: Create the builder**

Create `Core/Models/Sources/Models/SpotifyLink.swift`:

```swift
//
//  SpotifyLink.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Builds Spotify links without the Web API.
///
/// Resolving an exact album id needs an authenticated search request, which in
/// Development Mode only succeeds for the handful of allowlisted accounts. A
/// search URL needs no token at all, so the link works for every user — it lands
/// on search results rather than the album page, which is the accepted trade.
public enum SpotifyLink {
    private static let searchBase = "https://open.spotify.com/search/"

    public static func search(title: String, artist: String) -> URL? {
        let query = "\(title) \(artist)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        let collapsed = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard let encoded = collapsed.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: " "))
        ) else { return nil }

        return URL(string: searchBase + encoded)
    }
}
```

- [ ] **Step 4: Rewrite the deep-link resolution**

In `AlbumDetailsDataModel.swift`, replace the `.spotify` case inside `resolvePlayUrl()` with:

```swift
        case .spotify:
            playUrl = SpotifyLink.search(
                title: album.appleMusicAlbumData.title,
                artist: album.appleMusicAlbumData.artist
            )
```

The `appUrl` / `webUrl` / `canOpenURL` block goes away entirely: `open.spotify.com` links already open the Spotify app when it is installed, via universal links.

Confirm `import Models` is present at the top of the file; add it if not.

- [ ] **Step 5: Verify**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED. If `UIKit` is now unused in this file, remove the import.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Build Spotify album links from search URLs instead of the API"
```

---

## Task 13: Delete the recently-played probe

`fetchRecentlyPlayed()` is declared in two protocols and implemented across three layers. Nothing in `Presentation/` calls it.

**Files:**
- Modify: `Data/Repositories/MusicRepository/Sources/MusicRepository/MusicRepository.swift`
- Modify: `Domain/SettingUseCases/Sources/SettingUseCases/GetSettingsUseCase.swift`

- [ ] **Step 1: Confirm it is still unused**

```bash
grep -rn "fetchRecentlyPlayed()" --include="*.swift" Presentation/ Domain/ Data/ | grep -v "/.build/"
```

Expected: matches only in the declarations and implementations you are about to delete. If a caller appears, stop and reassess.

- [ ] **Step 2: Remove from the repository**

In `MusicRepository.swift`, delete `func fetchSpotifyRecentlyPlayed() async throws` from `MusicRepositoryProtocol` and delete its implementation.

- [ ] **Step 3: Remove from the use case**

In `GetSettingsUseCase.swift`, delete `func fetchRecentlyPlayed() async throws` from `GetSettingsUseCaseProtocol` and delete its implementation.

- [ ] **Step 4: Verify and commit**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

```bash
git add -A
git commit -m "Delete unused Spotify recently-played probe"
```

---

## Task 14: Rename the session check and carry premium status

**Files:**
- Modify: `Data/Repositories/MusicRepository/Sources/MusicRepository/MusicRepository.swift`
- Modify: `Domain/SettingUseCases/Sources/SettingUseCases/GetSettingsUseCase.swift`

- [ ] **Step 1: Update `SpotifyAuthorizationInfo`**

In `MusicRepository.swift`, replace the struct with:

```swift
public struct SpotifyAuthorizationInfo: Sendable {
    public let isAuthorized: Bool
    public let premium: SpotifyPremiumStatus

    public init(isAuthorized: Bool, premium: SpotifyPremiumStatus) {
        self.isAuthorized = isAuthorized
        self.premium = premium
    }
}
```

- [ ] **Step 2: Update the protocol and implementations**

In `MusicRepositoryProtocol`, replace `func isSpotifyTokenAvailable() async -> Bool` with:

```swift
    func hasStoredSpotifySession() async -> Bool
```

Then update the two implementations:

```swift
    public func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo {
        Logger.musicRepository.info("Requesting Spotify authorization")

        let result = try await spotifyService.requestAuthorization()

        return await SpotifyAuthorizationInfo(
            isAuthorized: result.isAuthorized,
            premium: result.premium
        )
    }

    public func hasStoredSpotifySession() async -> Bool {
        await spotifyService.hasStoredSession()
    }
```

- [ ] **Step 3: Update the settings use case**

In `GetSettingsUseCase.swift`, replace `loadSpotifyStatus()` with:

```swift
    /// Local only — no network. Settings must not fire a Spotify request every
    /// time it opens. The Firebase flag says the user connected; the Keychain
    /// says we still hold credentials for them.
    public func loadSpotifyStatus() async throws -> Bool {
        guard let userId = try await swiftDataManager.getCurrentUserId() else {
            return false
        }
        let profile = try await getLoginUseCase.getUserProfile(userId: userId)
        let firebaseFlag = profile?.hasSpotifyConnection == true
        let hasSession = await musicRepository.hasStoredSpotifySession()
        return firebaseFlag && hasSession
    }
```

- [ ] **Step 4: Verify**

Run `mcp__xcode__BuildProject`. Expected: errors in `SetSettingsUseCase.swift` and `GetSplashUseCase.swift` where `hasSpotifyPremium` is read from the auth result. Task 15 fixes them.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Rename Spotify token check and carry premium status through the repository"
```

---

## Task 15: Persist premium as unknown-safe

**Files:**
- Modify: `Domain/SettingUseCases/Sources/SettingUseCases/SetSettingsUseCase.swift`
- Modify: `Domain/SplashUseCases/Sources/SplashUseCases/GetSplashUseCase.swift`

- [ ] **Step 1: Update `connectSpotify`**

In `SetSettingsUseCase.swift`, replace the premium lines inside `connectSpotify()`:

```swift
        // `nil` when the check couldn't be completed — never persist a failed
        // check as "not premium", which is what the old Bool did.
        let isPremium = await authResult.premium.isPremium

        let existingProfile = try await getLoginUseCase.getUserProfile(userId: userId)
        let updatedProfile = FirebaseUserProfile(
            email: existingProfile?.email,
            firstName: existingProfile?.firstName,
            lastName: existingProfile?.lastName,
            hasAppleMusicSubscription: existingProfile?.hasAppleMusicSubscription,
            hasSpotifyConnection: true,
            hasSpotifyPremium: isPremium ?? existingProfile?.hasSpotifyPremium,
            mainMusicPlayer: existingProfile?.mainMusicPlayer
        )

        try await setLoginUseCase.saveUserProfile(userId: userId, profile: updatedProfile)
        Logger.settings.info("Spotify connected, premium: \(String(describing: isPremium))")

        return true
```

- [ ] **Step 2: Update `reconnectSpotify`**

In `GetSplashUseCase.swift`, apply the same change inside `reconnectSpotify()`:

```swift
        let isPremium = await authResult.premium.isPremium
        let existingProfile = try await getLoginUseCase.getUserProfile(userId: userId)
        let updatedProfile = FirebaseUserProfile(
            email: existingProfile?.email,
            firstName: existingProfile?.firstName,
            lastName: existingProfile?.lastName,
            hasAppleMusicSubscription: existingProfile?.hasAppleMusicSubscription,
            hasSpotifyConnection: true,
            hasSpotifyPremium: isPremium ?? existingProfile?.hasSpotifyPremium,
            mainMusicPlayer: existingProfile?.mainMusicPlayer
        )
        try await loginRepository.saveUserProfile(userId: userId, profile: updatedProfile)
        return true
```

- [ ] **Step 3: Add a premium-refresh entry point**

Still in `GetSplashUseCase.swift`, add to `GetSplashUseCaseProtocol`:

```swift
    func refreshSpotifyPremium(_ premium: SpotifyPremiumStatus) async
```

And implement it on the actor:

```swift
    /// Writes a freshly observed premium status to the profile. Called on every
    /// launch from the connection check, so upgrading to Premium is picked up
    /// without reconnecting. Unknown is ignored rather than written.
    public func refreshSpotifyPremium(_ premium: SpotifyPremiumStatus) async {
        guard let isPremium = await premium.isPremium else { return }
        do {
            guard let userId = try await swiftDataManager.getCurrentUserId() else { return }
            let existingProfile = try await getLoginUseCase.getUserProfile(userId: userId)
            guard existingProfile?.hasSpotifyPremium != isPremium else { return }

            let updatedProfile = FirebaseUserProfile(
                email: existingProfile?.email,
                firstName: existingProfile?.firstName,
                lastName: existingProfile?.lastName,
                hasAppleMusicSubscription: existingProfile?.hasAppleMusicSubscription,
                hasSpotifyConnection: existingProfile?.hasSpotifyConnection,
                hasSpotifyPremium: isPremium,
                mainMusicPlayer: existingProfile?.mainMusicPlayer
            )
            try await loginRepository.saveUserProfile(userId: userId, profile: updatedProfile)
            Logger.splash.info("Spotify premium refreshed to \(isPremium)")
        } catch {
            Logger.splash.error("Failed to refresh Spotify premium: \(error)")
        }
    }
```

Confirm `import SpotifyService` is present in `GetSplashUseCase.swift` for `SpotifyPremiumStatus`; add it if not.

- [ ] **Step 4: Verify and commit**

Run `mcp__xcode__BuildProject`. Expected: an error in `SplashDataModel.swift` for the non-exhaustive `switch` over the new state. Task 16 fixes it.

```bash
git add -A
git commit -m "Persist Spotify premium as unknown-safe and refresh it on launch"
```

---

## Task 16: Spotify stops blocking launch

This is the fix for the reported logout loop. Today any transient failure at launch sets `shouldComplete = false` and demands a reconnect.

The approved spec puts the re-auth prompt in **Settings only**, so the splash reconnect flow goes away entirely rather than becoming a non-blocking alert. Settings already owns a working reconnect path via `connectSpotify()`, which makes the splash copy redundant.

**Files:**
- Modify: `Presentation/Splash/Sources/Splash/SplashDataModel.swift`
- Modify: `Presentation/Splash/Sources/Splash/AlertType.swift`
- Modify: `Presentation/Splash/Sources/Splash/SplashAlertButtons.swift`
- Modify: `Presentation/Splash/Sources/Splash/SplashView.swift`
- Modify: `Domain/SplashUseCases/Sources/SplashUseCases/GetSplashUseCase.swift`

- [ ] **Step 1: Replace the Spotify gate**

In `SplashDataModel.continueAfterMusicKitGate()`, replace the whole `if musicPlayerManager.current == .spotify { ... }` block with:

```swift
        // Step 4: If the main player is Spotify, check the saved session for
        // telemetry and premium freshness — but never block launch and never
        // prompt here. A network blip is not a logout, and treating it as one is
        // what forced users to reconnect repeatedly. Re-auth lives in Settings.
        if musicPlayerManager.current == .spotify {
            switch await getSplashUseCase.verifySpotifyConnection() {
            case .connected(let premium):
                Logger.splash.info("Spotify connection verified")
                await getSplashUseCase.refreshSpotifyPremium(premium)
            case .unavailable:
                Logger.splash.info("Spotify unreachable right now — continuing, session left intact")
            case .notAllowlisted:
                Logger.splash.error("Spotify account not on the Development Mode allowlist — continuing")
            case .notConnected, .needsReauth:
                Logger.splash.info("Spotify session needs attention — surfaced in Settings, launch continues")
            }
        }
```

No `shouldComplete = false`, no `alertType`, no `return`. Loading proceeds in every branch.

- [ ] **Step 2: Delete the splash reconnect flow**

In `SplashDataModel.swift`, delete `func reconnectSpotify() async -> Bool` and `func skipSpotifyReconnect() async` in full.

- [ ] **Step 3: Delete the alert case**

In `AlertType.swift`, delete `case spotifyReconnect` and its line in the `id` switch.

- [ ] **Step 4: Delete the alert buttons**

In `SplashAlertButtons.swift`, delete the `case .spotifyReconnect:` branch and the now-unused `onReconnectSpotify` and `onSkipSpotify` stored properties.

- [ ] **Step 5: Update the call site**

In `SplashView.swift`, remove the `onReconnectSpotify:` and `onSkipSpotify:` arguments from the `SplashAlertButtons(...)` initializer. Build errors will point at the exact lines.

- [ ] **Step 6: Delete the use case entry point**

In `GetSplashUseCase.swift`, delete `func reconnectSpotify() async throws -> Bool` from `GetSplashUseCaseProtocol` and delete its implementation.

- [ ] **Step 7: Confirm nothing else referenced it**

```bash
grep -rn "reconnectSpotify\|skipSpotifyReconnect\|spotifyReconnect" --include="*.swift" . | grep -v "/.build/"
```

Expected: no matches.

- [ ] **Step 8: Verify and commit**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

```bash
git add -A
git commit -m "Stop Spotify from blocking launch and move re-auth to Settings"
```

---

## Task 17: Distinguish failed recents from empty recents

Today a failed fetch and a genuinely empty history both render as "no section", so a rate-limited request looks like the user listened to nothing.

**Files:**
- Modify: `Data/Repositories/AccountRepository/Sources/AccountRepository/AccountRepository.swift`
- Modify: `Presentation/Account/Sources/Account/AccountView/AccountDataModel.swift`

- [ ] **Step 1: Stop swallowing the error in the repository**

In `AccountRepository.swift`, replace `recentlyListened(for:ratings:)` with:

```swift
    /// Fetches recently-listened albums and badges each with the caller-supplied
    /// ratings. Rethrows so the caller can tell "this failed" from "this is
    /// empty" — collapsing the two made rate-limited fetches look like an empty
    /// listening history. A `nil` player (none selected) is genuinely empty.
    private func recentlyListened(for player: MusicPlayer?, ratings: [String: Double]) async throws -> [AlbumModel] {
        guard let player else { return [] }
        let musicData = try await musicRepository.fetchRecentlyListenedAlbums(for: player)
        var seenIds = Set<String>()
        let albums = musicData.compactMap { data -> AlbumModel? in
            guard seenIds.insert(data.id).inserted else { return nil }
            return AlbumModel(id: data.id, appleMusicAlbumData: data, firebaseAlbumData: nil, userRating: ratings[data.id])
        }
        Logger.accountRepository.info("Loaded \(albums.count) recently listened albums for \(player.rawValue)")
        return albums
    }
```

- [ ] **Step 2: Update all three call sites**

`recentlyListened` is called from three places. Making it `throws` touches every one.

At `getRecentlyListenedAlbums(for:)` (already `throws` — let it propagate, this is the path the Account view uses):

```swift
        return try await recentlyListened(for: player, ratings: ratings)
```

At the early-return branch in the aggregate load:

```swift
            return (rated: [], recentlyListened: (try? await recentlyListened(for: player, ratings: [:])) ?? [])
```

And at the concurrent aggregate load, where the `try` moves to the consumption site:

```swift
        async let ratedTask = albums(forIds: entries.map(\.albumId))
        async let recentTask = recentlyListened(for: player, ratings: ratingsMap)
        return await (rated: ratedTask, recentlyListened: (try? await recentTask) ?? [])
```

The aggregate load stays tolerant on purpose — a failed recents fetch must not fail the whole profile load. Only the dedicated `getRecentlyListenedAlbums` path propagates, because that is the one whose caller can render the difference.

- [ ] **Step 3: Surface the distinction in the Account view model**

In `AccountDataModel.swift`, add a stored property beside the existing flags:

```swift
    var recentlyListenedFailed = false
```

Then replace `fetchRecentlyListenedAlbums()` with:

```swift
    private func fetchRecentlyListenedAlbums() async -> [AlbumModel] {
        guard let player = musicPlayerManager.current else {
            Logger.account.info("No main music player selected; skipping recently listened")
            recentlyListenedFailed = false
            return []
        }

        do {
            let albums = try await getAccountUseCase.getRecentlyListenedAlbums(for: player)
            recentlyListenedFailed = false
            return albums
        } catch {
            // Distinct from "no history" — the section can say so rather than
            // silently vanishing.
            Logger.account.error("Failed to load recently listened albums: \(error)")
            recentlyListenedFailed = true
            return []
        }
    }
```

And in `reloadRecentlyListenedAlbums()`, keep the section visible when a fetch failed so the user sees something happened:

```swift
    func reloadRecentlyListenedAlbums() async {
        let recents = await fetchRecentlyListenedAlbums()
        self.recentlyListenedAlbums = recents
        self.isShowingRecentlyListenedSection = !recents.isEmpty || recentlyListenedFailed
    }
```

- [ ] **Step 4: Verify and commit**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

```bash
git add -A
git commit -m "Distinguish failed recently-listened fetches from empty history"
```

---

## Task 18: Surface Spotify session state in Settings

Settings is now the only place a broken Spotify session is surfaced, so it must cover both cases: an account that isn't allowlisted, and a session that genuinely needs re-authorization. Per the spec, neither notice is permanent — each appears only when that state is actually observed.

**Files:**
- Modify: `Presentation/Settings/Sources/Settings/SettingsDataModel.swift`
- Modify: `Presentation/Settings/Sources/Settings/SettingsView.swift`

- [ ] **Step 1: Track the state**

In `SettingsDataModel.swift`, add beside the other flags:

```swift
    /// What the last connection check actually said. Drives the inline notice
    /// under the Spotify row; nil means nothing to report.
    var spotifyNotice: SpotifyNotice?

    enum SpotifyNotice {
        case notAllowlisted
        case needsReauth

        var message: String {
            switch self {
            case .notAllowlisted:
                "This Spotify account isn't enabled for BeatRate yet. Spotify access is currently limited to approved accounts."
            case .needsReauth:
                "Your Spotify session expired. Reconnect to keep your listening history up to date."
            }
        }
    }
```

- [ ] **Step 2: Populate it on load**

Replace `loadUserProfile()` with:

```swift
    func loadUserProfile() async {
        do {
            isAppleMusicConnected = try await getSettingsUseCase.loadAppleMusicStatus()
            isSpotifyConnected = try await getSettingsUseCase.loadSpotifyStatus()
            await refreshSpotifyNotice()
            Logger.settings.info("Loaded user profile, Apple Music: \(self.isAppleMusicConnected), Spotify: \(self.isSpotifyConnected)")
        } catch {
            Logger.settings.error("Failed to load user profile: \(error)")
        }
    }

    /// Only meaningful once we hold credentials. A transient failure reports
    /// nothing — the user does not need to know the network hiccuped.
    private func refreshSpotifyNotice() async {
        guard isSpotifyConnected else {
            spotifyNotice = nil
            return
        }
        switch await getSplashUseCase.verifySpotifyConnection() {
        case .notAllowlisted: spotifyNotice = .notAllowlisted
        case .needsReauth, .notConnected: spotifyNotice = .needsReauth
        case .connected, .unavailable: spotifyNotice = nil
        }
    }
```

`getSplashUseCase` is already a stored dependency on this type — no new injection needed.

- [ ] **Step 3: Clear the notice after a successful reconnect**

In `connectSpotify()`, add the refresh so the notice disappears once the user fixes it:

```swift
    func connectSpotify() async {
        isConnectingSpotify = true
        defer { isConnectingSpotify = false }

        do {
            isSpotifyConnected = try await setSettingsUseCase.connectSpotify()
            await refreshSpotifyNotice()
        } catch {
            Logger.settings.error("Failed to connect Spotify: \(error)")
        }
    }
```

- [ ] **Step 4: Show the notice**

In `SettingsView.swift`, directly below the Spotify row that uses `dataModel.isSpotifyConnected`, add:

```swift
                    if let notice = dataModel.spotifyNotice {
                        Text(notice.message)
                            .textStyle(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Spacing.lg)
                    }
```

Use design-system tokens only — see `Core/CoreUI/DesignSystem.md`. If `.caption` is not the correct text style token in this codebase, pick the nearest existing one rather than inventing a token, and do not fall back to `.font(.system(size:))`.

- [ ] **Step 5: Verify and commit**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED.

```bash
git add -A
git commit -m "Surface Spotify allowlist and re-auth state in Settings"
```

---

## Task 19: Final verification

- [ ] **Step 1: Confirm nothing references the deleted surface**

```bash
grep -rn "SpotifyError\|hasAccessToken\|searchSpotifyAlbumId\|fetchSpotifyRecentlyPlayed\|isSpotifyTokenAvailable\|reconnectSpotify\|spotifyReconnect\|hasSpotifyPremium:" --include="*.swift" . | grep -v "/.build/"
```

Expected: matches only in `FirebaseUserProfile.swift` (the stored field, which keeps its name) and the `SetSettingsUseCase` / `GetSplashUseCase` call sites that set it. Any other hit is a leftover — fix it.

- [ ] **Step 2: Full build**

Run `mcp__xcode__BuildProject`. Expected: BUILD SUCCEEDED with no warnings introduced by this work.

- [ ] **Step 3: Run the test suite in Xcode**

Open `BeatRate.xcodeproj` and press ⌘U against a real device. All `SpotifyServiceTests` and `ModelsTests` must pass. This cannot be run from the CLI in this repo — see "Before you start".

- [ ] **Step 4: Manual verification against the real bugs**

- [ ] Launch with the device in airplane mode and Spotify as the main player. **The app must reach the home screen and must not ask you to reconnect.** This is the headline fix.
- [ ] Restore connectivity, background the app for over an hour, reopen it, and confirm recently-listened still loads without a reconnect prompt.
- [ ] Open an album's play button with Spotify selected and confirm it opens Spotify search for that album, on an account that is *not* allowlisted.
- [ ] Sign in on an account that was connected before this change and confirm it is **not** signed out — this exercises the Keychain migration in Task 5.
- [ ] If Task 1 found `product` present in `/me`, toggle a Premium subscription and confirm the flag updates on next launch without reconnecting.

- [ ] **Step 5: Open the PR**

```bash
git push -u origin task/spotify-service-refactor
gh pr create --base development --title "Refactor Spotify service into session and client" --body "$(cat <<'BODY'
## Summary

Splits `SpotifyService` into a `SpotifySession` actor (token lifecycle) and a stateless `SpotifyClient` (endpoints and retry policy) behind a facade, and replaces the error handling that collapsed five distinct failures into a single `.invalid` state.

That collapse was the root cause of all three reported bugs: a dropped connection at launch was indistinguishable from a dead session, so the app demanded a Spotify reconnect whenever the network blipped.

## Changes

- `SpotifyFailure` taxonomy separating transient failure from session loss, 403, and rate limiting
- Retry policy honouring `Retry-After` on 429 and backing off on 5xx
- Premium is a re-checked tri-state; a failed check is `unknown`, never `false`
- Proactive token refresh via stored expiry, replacing the guaranteed 401 per hour
- Keychain stores one JSON item with `kSecAttrAccessibleAfterFirstUnlock`, with migration from the old key pair
- Spotify no longer blocks app launch
- Album links use `open.spotify.com` search URLs — no API, so they work for all users rather than allowlisted ones
- Deletes the album search path and the unused recently-played probe

## Platform note

The app is in Spotify Development Mode, capped at 5 allowlisted users, with no path to Extended Quota for an individual developer. Spotify recently-played is therefore an allowlisted beta; all other users fall through to the existing MusicKit path.

## Testing

Unit tests cover the classifier, token expiry, session refresh, and every row of the retry policy. Manual verification steps are in the plan.

Spec: `docs/superpowers/specs/2026-08-30-spotify-service-refactor-design.md`
BODY
)"
```

---

## Traceability

| Symptom | Fixed by |
|---|---|
| Premium shows wrong | Tasks 10, 15 — tri-state, re-checked every launch, `nil` never persisted as `false` |
| Recents sometimes missing | Tasks 9, 17 — retry policy, and failed vs empty made distinct |
| Keeps logging out | Tasks 8, 9, 16 — transient never clears tokens, launch never blocks, and the splash reconnect prompt is gone |
| Silent breakage for non-allowlisted users | Tasks 10, 18 — `.notAllowlisted` and `.needsReauth` surfaced in Settings instead of swallowed |
