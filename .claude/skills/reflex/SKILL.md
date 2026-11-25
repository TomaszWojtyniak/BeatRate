---
name: reflex
description: Use when exploring, testing or changing BeatRate's Reflex screens — run the headless app (./cli, ls/do), add fixtures, migrate a DataModel to a view model with an introspection node, write behavior journeys, or drive the Debug app over localhost:7777.
---

# Reflex in BeatRate

Migrated screens run headlessly. Each is a view model exposed as a node (name, state as JSON, actions). Read and drive the app through that contract, not through pixels. Legacy screens (tabs, player picker, login sheet) show up as leaves until their phase migrates them.

## Run

```sh
./cli                                   # a fresh guest on behavior/fixtures/catalog.discovery.json
./cli behavior/fixtures/device.signedIn.json behavior/fixtures/catalog.discovery.json
./test Presentation/Splash              # that package's tests, the import guard, then every journey
```

One command per line:

```
ls                          # the focused node: name, state JSON, actions
do Continue                 # an action without input
do AllowAnalytics           # actions of every node on the path are available at the focus
do dismiss                  # camelCase = lent by a container (the login sheet)
{"cmd":"ls"}                # JSON lines get one-line JSON answers (what behavior/sdk.mjs uses)
```

`printf 'ls\ndo Continue\nls\n' | ./cli …` works for one-shot checks, but effects need time between commands; use a journey for anything that waits. Exit code 3 with `network violation: …` on stderr means a request had no fixture.

The Debug app answers the same protocol and the UI follows:

```sh
printf 'ls\n' | nc -w 1 127.0.0.1 7777
```

## The tree today

`App` (the `AppNavigator`; no actions) → the login sheet `LoginPrompt` (`dismiss`) while it is up, else `AnalyticsConsent` (`AllowAnalytics`, `DenyAnalytics`) while it covers the tabs, else the screen: `Splash` / `MusicExplainer` (`Continue`), or the legacy leaves `PlayerPicker` and `Tabs`. Leaves show the app's state (`isLoggedIn`, `hasPlayer`, `analyticsConsent`, …).

## Fixtures

JSON files in `behavior/fixtures/`, merged in order: later files win leaf by leaf, `null` removes a key, arrays replace. Unknown keys, unknown values and wrong types are refused with their path. Compose small files instead of copying big ones.

| Key | Drives |
| --- | --- |
| `db` | the RTDB tree (export shape): `sections`, `albums`, `album_ratings`, `users` |
| `dbFailures.reads` / `.writes`, `dbDelayMs` | failing paths (exact), delay of every RTDB call |
| `music.authorization`, `music.answer` | Apple Music access before / after the system prompt: `notDetermined`, `denied`, `restricted`, `authorized` (default) |
| `music.subscription`, `music.albums.<id>` | subscription flag; catalog albums (`title`/`artist` must match `db`) |
| `device.firebaseUid`, `device.keychain.appleUserID`, `device.appleIDState` | Firebase session, Keychain Apple ID, `authorized`/`revoked`/`notFound`/`transferred` |
| `device.loggedInUserId`, `device.defaults` | the SwiftData login row; UserDefaults (`analyticsConsent`, `mainMusicPlayer.<uid>`) |
| `timing.retryDelayMs` | the splash's retry delay (default 0) |

Spotify has no fixtures yet: any Spotify request is a violation.

## Migrate a screen

1. A journey in `behavior/` first, with its fixtures.
2. `<Name>ViewModel` in the package's logic target: `@Observable public final class`, `State` (Encodable, meanings not texts), public `Action`, internal `Message` (`.viewAction` + effect results), `update` as the only writer. Copy the internal `ViewModel` protocol into the module. Load in `init`. Effects are `Task`s that `send(message:)`; callbacks into a parent run from an effect, never inside `update` (a parent that redraws reads the state mid-write: exclusivity crash).
3. `<Name>ViewModel+Introspection.swift`: one PascalCase action per `Action` case, always listed; inputs are `nonisolated struct <Action>Input: IntrospectionInput`.
4. The parent creates it (today `AppNavigator`), never a view.
5. Views in the `<Name>UI` target (`#if os(iOS)`), reading `state`, sending actions, built from design-system tokens.
6. Tests of `update` (transitions and no-ops); add the package to `./test` and its logic sources to the guard. Delete the old DataModel and its tests once every case has moved.

Reference: `Presentation/Splash` (screen) and `Presentation/AppRoot` (navigator, root).

## Write a journey

```js
const s = createBehaviorSession({ fixtures: [fixture('device.guest'), fixture('catalog.discovery'), fixture('music.undecided')] });
t.after(() => s.close());
await s.precondition('MusicExplainer');
await s.do({ action: 'Continue', expectation: ({ name }) => assert.equal(name, 'AnalyticsConsent') });
```

- One journey per fixture set.
- Expect something the action changes; an expectation already true before it proves nothing.
- `precondition`/`do` poll `ls` for up to 2 s, then fail with the last state seen. Read it before touching code.
- Always `t.after(() => s.close())`: a violation caused by the last step shows on the next command.
