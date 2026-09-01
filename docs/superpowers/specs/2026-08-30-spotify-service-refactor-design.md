# Spotify Service Refactor — Design

**Date:** 2026-08-30
**Branch:** `task/spotify-service-refactor`
**Status:** Approved, ready for implementation planning

---

## Problem

Three reported symptoms:

1. Premium status displays incorrectly.
2. Recently-listened albums do not always appear.
3. The Spotify session appears to log out, forcing repeated reconnection.

All three trace to a single class of defect: the module collapses five materially
different failures into one undifferentiated error state, and callers then treat
that state as "the session is dead."

## Platform context (verified 2026-08-30)

BeatRate's Spotify app is in **Development Mode**. This is a hard constraint on
the design, not a configuration to be fixed:

- Development Mode allows **5 authenticated users**, each individually allowlisted
  in the developer dashboard. The app owner must hold Spotify Premium.
- **Extended Quota Mode** has been organization-only since 2025-05-15 and requires
  a legally registered business, an already-launched service, 250,000 MAU, presence
  in key Spotify markets, and demonstrated commercial viability. Review takes up to
  six weeks. There is **no intermediate tier**.
- As of the July 2026 quota update, quota is counted **per developer account**, so
  all Development Mode Client IDs share one quota pool. Exceeding it returns HTTP
  429 with `"reason": "QUOTA_EXCEEDED"`.
- The February 2026 Dev Mode changes strip sensitive fields from `/me` responses
  (`country`, `email`, and others). Whether `product` — the field this app reads to
  determine Premium — survives in Development Mode is **not documented**. See
  "Diagnostics" below.

Consequence: an individual developer cannot lawfully exceed 5 Spotify users. The
design accepts this and makes the limit visible rather than pretending it away.

### A non-allowlisted user reproduces all three bugs exactly

A user who authenticates but is not on the dashboard allowlist receives **403 on
every API call**. Traced through current code, a 403 causes:

- `checkPremiumStatus` to return `false` — symptom 1
- recently-played to throw into a silent `[]` — symptom 2
- `verifyConnection` to return `.invalid`, forcing reconnect — symptom 3

**Verify the allowlist before implementing anything.** It may account for a
substantial share of the reported behavior on its own.

## Decisions taken

| Question | Decision |
|---|---|
| Role of Spotify in the product | Data-only. No playback. Recently-listened data plus album deep links. |
| Recently-played for >5 users | Not possible. Spotify recents remain an allowlisted beta; all other users fall through to the existing MusicKit path. |
| Album deep links | Built from title + artist as a search URL. No API call, no auth, no quota. Works for every user. |
| SDK vs Web API | Stay on the Web API. Spotify's mobile *streaming* SDKs were sunset in September 2022; the surviving App Remote SDK requires the Spotify app installed plus Premium and only remote-controls playback. It provides none of `/me`, recently-played, or search, so it would be additive complexity covering zero current features. |
| Refactor shape | Structural split into session + client behind a stable facade. |

## Non-goals

- Adding the Spotify App Remote SDK.
- In-app Spotify playback.
- Working around the 5-user cap.
- Changing the Apple Music / MusicKit path, which remains the primary and
  mandatory source.
- Rewriting `SpotifyAlbumMatcher`, which is still required to map Spotify recents
  onto Apple Music catalog entries.

---

## Architecture

```
SpotifySession   (actor)   — owns all token state, nothing else
  authorize() -> Tokens          PKCE + web sheet + code exchange
  validAccessToken() -> String   proactive refresh at T-60s
  refreshedToken() -> String     forced refresh, after a 401
  signOut()                      clears Keychain
  hasStoredSession() -> Bool     local only, no network

SpotifyClient    (struct)  — stateless endpoints; no Keychain, no PKCE
  get<T>(_:session:) -> T        token -> request -> retry policy -> decode

SpotifyService   (actor)   — thin facade conforming to SpotifyServiceProtocol
  requestAuthorization() / verifyConnection() / fetchRecentlyPlayedAlbums()
  hasStoredSession()
```

Method names on the public protocol are unchanged apart from the renames and
deletions listed under "Deletions". `signOut()` stays internal to `SpotifySession`
— it is called when a refresh is genuinely rejected, and no caller needs it, so no
public `disconnect()` is added.

The facade keeps `MusicRepository` and every layer above it structurally unchanged.
Note that `SpotifyConnectionState` itself gains cases and an associated value, so
the call sites that switch over it — `GetSplashUseCase.verifySpotifyConnection` and
`SplashDataModel` — must be updated. That is intended and is specified under
"Launch behavior".

The split exists to make the retry and refresh logic testable in isolation: `SpotifyClient` against a stub transport with
no Keychain, `SpotifySession` against a stub store with no network.

`SpotifySession` and `SpotifyService` are actors. `SpotifyClient` holds no mutable
state and stays a `Sendable` struct, matching the existing `SpotifyNetworkClient`.

Note: every local package sets `.defaultIsolation(MainActor.self)`, so struct
initializers called from these non-`@MainActor` actors require `await`. Those
`await` keywords are load-bearing and must not be removed.

## Error taxonomy

The central fix. Every `catch` in the module maps into this type; nothing collapses
into a generic failure again.

```swift
public enum SpotifyFailure: Error, Sendable {
    case noSession                               // no tokens stored
    case sessionExpired                          // refresh genuinely rejected
    case notAllowlisted                          // 403 — Dev Mode gate or missing scope
    case rateLimited(retryAfter: TimeInterval?)  // 429
    case transient(underlying: Error?)           // offline, timeout, 5xx — session is FINE
    case authCancelled                           // user dismissed the sheet
    case authorizationFailed                     // sheet could not start, or no code returned
}
```

`SpotifyError` is replaced by this. Mapping of the cases it currently carries:

| Existing `SpotifyError` | Becomes |
|---|---|
| `authorizationFailedToStart`, `missingAuthCode` | `.authorizationFailed` |
| `missingAccessToken` | `.noSession` |
| `refreshTokenMissing` | `.sessionExpired` |
| `tokenRefreshFailed` | `.sessionExpired` **or** `.transient`, split by cause |
| `tokenExchangeFailed` | `.authorizationFailed` or `.transient`, split by cause |
| `invalidResponse` | `.transient` |
| `requestFailed(statusCode:)` | classified per the request-policy table |

`ASWebAuthenticationSessionError.canceledLogin` maps to `.authCancelled`, which must
not be surfaced as an error — the user chose to dismiss.

The distinction that matters most: `.transient` must never cause token mutation or
a reconnect prompt.

## Connection state and premium

```swift
public enum SpotifyPremiumStatus: Sendable { case premium, free, unknown }

public enum SpotifyConnectionState: Sendable {
    case connected(premium: SpotifyPremiumStatus)
    case notConnected      // never connected
    case needsReauth       // session genuinely dead
    case unavailable       // transient — never prompt
    case notAllowlisted    // Dev Mode gate — distinct user-facing message
}
```

`verify()` decodes `/me` **once** and returns connection state and premium status
together. That request already fires on every launch and currently discards its
body, so Premium becomes self-correcting at no additional quota cost — replacing
today's behavior where it is computed once at connect time and frozen forever.

`FirebaseUserProfile.hasSpotifyPremium` is already `Bool?`. Write `nil` for
`.unknown` so a failed check can never be persisted as "free", which is what
happens today.

## Request policy (`SpotifyClient`)

| Response | Action |
|---|---|
| 200 | decode |
| 401 | one forced refresh, retry once; still 401 -> `.sessionExpired` and `signOut()` |
| 403 | `.notAllowlisted`, no retry |
| 429 | honor `Retry-After`, up to 2 retries, then `.rateLimited` |
| 502 / 503 / 504 | exponential backoff, up to 2 retries, then `.transient` |
| `URLError` offline / timeout | `.transient` immediately, no retry |
| other non-2xx | `.transient` |

`.transient` never touches stored tokens. This rule is what stops the false
logouts.

## Token lifecycle

Persist `expires_in` as an `expiresAt` date alongside the token pair.
`validAccessToken()` returns the cached token while more than 60 seconds remain and
refreshes otherwise. This removes the guaranteed 401 round-trip that currently
occurs on the first request after each token expiry — meaningful now that quota is
shared across all Client IDs on the account.

`performRefresh` must distinguish:

- Spotify rejects the grant (`invalid_grant`) -> `.sessionExpired`, clear the Keychain
- network failure -> `.transient`, **keep** the tokens

Today both become `.tokenRefreshFailed`, and nothing ever clears a dead session, so
`hasAccessToken()` keeps reporting "connected" indefinitely.

## Launch behavior

`SplashDataModel` currently sets `shouldComplete = false` and demands reconnection
whenever `verifySpotifyConnection()` is not `.connected`. New rule: **Spotify never
blocks app launch.**

```
.connected(premium)           -> persist premium if changed, continue
.unavailable, .notAllowlisted -> continue silently, log only
.needsReauth, .notConnected   -> continue; surface a dismissible prompt in Settings
```

Apple Music remains the mandatory authorization gate. Spotify is strictly additive.

## Keychain hardening

`KeychainManager` currently contains three near-identical save/load/delete triplets
and never sets an accessibility attribute.

- Collapse the triplets into generic `save(_:for:)` / `load(_:)` / `delete(_:)`
- Set `kSecAttrAccessibleAfterFirstUnlock` on all items
- Use `SecItemUpdate` when the item exists rather than delete-then-add
- Store the whole token set as one JSON item under a single `spotifyTokens` key,
  rather than separate access/refresh/expiry items — one item cannot half-write.
  Migrate the pre-refactor `spotifyAccessToken` / `spotifyRefreshToken` pair on
  first read so existing users are not signed out by this change.

Net deletion of roughly 60 lines. Existing Apple-user-ID behavior is preserved.

## Deletions

Verified to have no remaining consumers, or consumers being rewritten:

- `searchAlbumId`, `SpotifySearchResponse`, `SpotifyAPI.searchAlbum`,
  `Limit.search`, `Value.searchTypeAlbum`
- The matching pass-throughs in `MusicRepository`, `GetAlbumDetailsUseCase`, and
  both protocol declarations
- `fetchRecentlyPlayed()` — the probe call. Declared in two protocols, implemented
  across three layers, and **called by nothing in `Presentation/`**. Dead code.
- `hasAccessToken()` renamed to `hasStoredSession()`. "A string exists in the
  Keychain" was never the same as "connected", and the old name invited that
  reading at both call sites. The rename propagates through
  `MusicRepository.isSpotifyTokenAvailable` and `GetSettingsUseCase.loadSpotifyStatus`
  to its two consumers, `SettingsDataModel` and `MusicPlayerPickerDataModel`.
  It stays a local, no-network check: Settings must not issue a request every time
  it opens.

`AlbumDetailsDataModel` replaces its API lookup with a pure URL builder placed in
`Models`, producing `https://open.spotify.com/search/<title artist>`. No network
call, no auth, no `SpotifyService` import. The link begins working for all users
instead of five. It resolves to Spotify search results rather than the album page —
an accepted trade for universal coverage.

## UI decisions

Both items below were defaulted rather than specified, and each is a one-line
reversal:

- **Dev Mode disclosure.** Settings shows a "Spotify beta — limited to allowlisted
  accounts" note **only when `.notAllowlisted` is actually observed**, rather than
  permanently. Honest when it matters, no standing clutter otherwise.
- **Re-auth prompt placement.** `.needsReauth` surfaces in **Settings only**, not
  as a banner on Account. Fewer surfaces, and consistent with the decision that
  Spotify never blocks or interrupts.

## Testing

The split is what makes the behavior testable.

- `SpotifyClient`: one test per row of the request-policy table, against a
  protocol-injected stub transport. No Keychain, no network.
- `SpotifySession`: expiry boundary, proactive refresh, refresh coalescing under
  concurrent callers, `invalid_grant` clearing the Keychain, and network failure
  **not** clearing it.
- Existing PKCE and decoding tests carry over unchanged.

Tests live in the existing `SpotifyServiceTests` package. They cannot be executed
locally in this environment (no simulators, `swift test` fails on macOS SwiftData);
they must be kept building and run from Xcode.

## Diagnostics to run before implementation

1. **Confirm the dashboard allowlist.** Dashboard -> app -> Settings -> User
   Management. Every non-owner test account must appear by Spotify account email.
   A missing entry reproduces all three reported bugs.
2. **Confirm the redirect URI** is registered verbatim as `beatrate://spotify-callback`.
3. **Log the raw `/me` response body once** on a connected account and confirm
   whether `product` is present. If Development Mode strips it, Premium is not
   determinable client-side and must remain `.unknown` — the design already handles
   this, but it settles whether symptom 1 is fully fixable.

## Traceability

| Symptom | Root cause | Addressed by |
|---|---|---|
| Premium shows wrong | status code discarded in `checkPremiumStatus`; computed once and frozen into Firebase; possibly stripped from `/me` in Dev Mode | Tri-state premium, re-checked on every `verify()`; `nil` persisted for unknown |
| Recents sometimes missing | no retry on 429/5xx; failure indistinguishable from empty; strict matcher silently drops non-matches | Request policy with backoff; taxonomy surfaced so the UI can distinguish "failed" from "empty" |
| Keeps logging out | `verifyConnection` catch-all returning `.invalid`; refresh conflating offline with rejection; splash blocking on the result | `.transient` classification; refresh error separation; non-blocking launch |

**Not addressed, by nature:** the 5-user Development Mode cap, and `product`
possibly being unavailable in Development Mode. Both are platform limits. The
design surfaces them as `.notAllowlisted` and `.unknown` rather than silently
producing wrong values.
