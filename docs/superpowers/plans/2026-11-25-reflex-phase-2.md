# BeatRate → Reflex, faza 2: infrastruktura i pilot (korzeń + Splash)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Cel:** Start aplikacji, od splasha do zakładek, działa bez UI w `beatrate-cli` i na żywo przez `nc localhost 7777`. Pomiar pilota rozstrzyga bramkę G2 (go/no-go).

**Architektura:**
- Najpierw kopiujemy z repo Reflex `IntrospectionKit`, a do tego robimy fake'i krawędzi i loader fixtur.
- Potem `SplashDataModel` staje się `SplashViewModel` w kształcie Elm (`State` / `Action` / `Message` / `update`). Na tym etapie hostem jest jeszcze stary `AppView`.
- Na końcu korzeń `BeatRateApp(edges:)` z `AppNavigator` zastępuje `AppView` i `AppDataModel`. Dochodzą też CLI, serwer :7777 i podróże w Node.
- Zakładki, wybór odtwarzacza i arkusz logowania zostają starymi widokami. W Core są liśćmi bez własnych akcji.

**Stos:** Swift 6.4.2, Xcode 27.2, SwiftPM (`swift-tools-version: 6.4`), Swift Testing, Observation (`Observations`), Network (`NWListener`), Node 22 (`node --test`, bez zależności).

**Spec:** `docs/superpowers/specs/2026-11-24-reflex-migration-design.md`, sekcje:
- „Faza 2”;
- przykłady 2, 3, 7, 8 i 9;
- „Testy i weryfikacja” (lista parity, punkty 1–6 i 19);
- „Decyzje” (pytania 9, 10, 12, 13, 16–18, 21–23 oraz M1, M2, M5, M6).

**Referencja:** `TomaszWojtyniak/ReflexArchitecture_iOS` @ `befa64a`. Kopie plików z repo robimy z tej wersji: `git clone`, potem `git checkout befa64a`.

## Global Constraints

- Gałęzie zadań wycinamy z `feature/reflex-phase-2`, a PR-y idą do `feature/reflex-phase-2` (memory: reflex-branching). Do `development` nic nie trafia.
- Nowe pakiety tworzy użytkownik w Xcode (memory: user-creates-swift-packages). Krok „USER” podaje nazwę, ścieżkę i zależności, a wykonawca czeka na potwierdzenie.
- Pakiety mają `.iOS(.v27), .macOS(.v27)` i `.defaultIsolation(MainActor.self)`. Nie włączamy `NonisolatedNonsendingByDefault` ani `InferIsolatedConformances` (decyzja 15), chociaż repo Reflex je ma.
- Logika (`Splash`, `AppRoot`, `IntrospectionKit`, `BeatRateFixtures`, `beatrate-cli`) nie importuje SwiftUI, UIKit, Firebase* ani MusicKit. Pilnuje tego strażnik w `./test`.
- Targety `…UI` mają każdy plik w `#if os(iOS)`, a ich zależności od pakietów tylko na iOS mają `condition: .when(platforms: [.iOS])`. To ta sama zasada co dla `…Live` (decyzja fazy 2, nr 1).
- Protokół `ViewModel` to 10-liniowa kopia `internal` z repo (`Core/Sources/InventoryCore/ViewModel.swift`), jedna na moduł logiki (decyzja 9). Widok widzi tylko `state` i `send(action:)`.
- `update` nigdy nie woła synchronicznie `send(message:)` na tym samym ViewModelu. Efekty to `Task`, które wracają przez `send(message:)`. Jedynym polem poza `State` może być uchwyt `Task` (M5) albo podrzędny ViewModel (jak `home` w `TabNavigator` z repo).
- Stan trzyma znaczenia, nie teksty (decyzja 13). Lokalizacja zostaje w widoku.
- Zero zmian zachowania aplikacji. Zostają te same zdarzenia analityki (`screen_view` splasha i explainera, `permission_continue_tap`, `tab_selected`), klucze UserDefaults (`analyticsConsent`, `mainMusicPlayer.<uid>`) i ta sama kolejność kroków startu.
- Testy piszemy w Swift Testing, z nazwami-zdaniami w backtickach. Dublery trzymamy w `<Package>TestDoubles.swift`. `UserDefaults` w testach i w CLI: `UserDefaults(suiteName: FileManager.default.temporaryDirectory.appending(path: "<Nazwa>.\(UUID())").path)!`. Przed testami załaduj `swift-testing-expert`.
- Po każdym zadaniu: Xcode MCP `BuildProject` dla obu schematów (zapas: `xcodebuild … -quiet build` i kod wyjścia), a do tego `./test` z pakietami, których zadanie dotyka.
- Wymagamy 100% pokrycia linii logiki w dotkniętych modułach. Wyjątki: `IntrospectionServer` (sieć, test z repo zostaje) i `main` w CLI. Wyjątki nazywamy w opisie PR-a.

## Review Focus

1. **Podwójny start splasha:** `SplashViewModel` ładuje w `init`. Jeśli powstanie w `init` widoku albo w `body`, każde przerysowanie odpali drugie sprawdzenie poświadczeń i drugie pobranie. Dlatego tworzy go tylko obiekt żyjący raz na proces: `AppDataModel` w zadaniu 2.4, `AppNavigator` od zadania 2.5. Pilnuje tego test ``a second login starts a fresh splash and the first one is gone`` (2.5) i smoke w 2.6 (jeden log `Requesting MusicKit authorization` na start).
2. **Firebase przed korzeniem:** `@State var app = BeatRateApp(edges: .live())` powstaje przed `didFinishLaunching`. `FirebaseApp.configure()` i ustawienia trwałości RTDB muszą być pierwszymi liniami `Edges.live()`, bo inaczej pierwszy odczyt `sections` pada. Pilnuje tego smoke w 2.6: start po usunięciu aplikacji, Home ładuje sekcje. Przy okazji znika odłożony drobiazg 5 z przeglądu #48.
3. **Jeden konsument strumienia logowania:** `observeLoginState()` oddaje jeden współdzielony `AsyncStream`. Po 2.5 subskrybuje go tylko `AppNavigator`, a `AppDataModel` znika razem ze swoją subskrypcją. Dwóch konsumentów to zgubione zdarzenia wylogowania. Pilnuje tego podróż ``revoked Apple ID logs out completely and enters as a guest`` (2.7).
4. **Serwer :7777 poza Release:** `IntrospectionServer` jest w `#if DEBUG`, a jego uruchomienie w `BeatRateMain` też. Pilnuje tego krok 2.6: `strings` na buildzie Release nie znajduje `IntrospectionServer`.
5. **Fixtura bez sieci:** każde żądanie bez fixtury (album bez `music.albums`, dowolne żądanie Spotify, `URLSession`) kończy CLI kodem 3, także wtedy, gdy aplikacja złapała błąd. Pilnują tego testy `NetworkGuard` (2.2) i ``an album without a music fixture ends the cli with code 3`` (2.7).

## Odstępstwa od specu

- **Kolejność PR-ów:** Splash przed korzeniem, nie odwrotnie. `AppNavigator` potrzebuje `SplashViewModel`, a Splash w nowym kształcie da się wydać pod starym `AppView`. Każdy PR zostawia działającą aplikację.
- **Węzeł `Analytics` (decyzja 23):** przesuwamy go na fazę 4. Podróż zgody sprawdza `analyticsConsent` w stanie węzła `App`. `FakeAnalyticsBackend` już nagrywa zdarzenia, więc w fazie 4 węzeł tylko je pokaże.
- **Sekcja `http` fixtur:** pusta do czasu pierwszej podróży ze Spotify. `FakeSpotifyTransport` zgłasza naruszenie przy każdym żądaniu. Punkt parity 4 (weryfikacja Spotify nie blokuje startu) zostaje w istniejących testach Swift.
- **Komunikat po 3 nieudanych pobraniach:** `SplashDataModel` ustawia `errorMessage` i od razu kończy splash, więc tekst nigdy się nie pokazuje. Nie przenosimy go do stanu.
- **Strażnik binarki Release:** jednorazowo w zadaniu 2.6, nie w `./test`. Build Release trwa minuty, a `./test` ma limit 30 s z G2.
- **Zdarzenia `screen_view`:** splash i explainer logują je w `update`, przy wejściu w fazę. Pełne `screen_view` z nawigacji (decyzja 10) to faza 3.

## Decyzje fazy 2 (zatwierdzone 2026-11-25, wszystkie rekomendacje)

1. Targety `…UI`: pliki w `#if os(iOS)`, zależności iOS z `.when(platforms: [.iOS])`.
2. Kolejność PR-ów: Splash przed korzeniem.
3. Węzeł `Analytics`: faza 4.
4. Strażnik Release: jednorazowo w 2.6.
5. Wykonanie: natywnie (superpowers:executing-plans), jeden przegląd całej gałęzi przed PR-em.

## Gałęzie i PR-y

| PR | Gałąź (od `feature/reflex-phase-2`) | Zadania |
| --- | --- | --- |
| PR 1 | `task/reflex-introspection-kit` | 2.1–2.3 |
| PR 2 | `task/reflex-splash` | 2.4 |
| PR 3 | `task/reflex-app-root` | 2.5–2.7 |
| PR fazy | `feature/reflex-phase-2` → `feature/reflex` | po G2 |

```bash
# Jeden pakiet logiki na macOS (od 2.3 także build CLI i podróże)
./test Presentation/Splash

# Testy targetu iOS na symulatorze (iPhone Duo, UDID 9CE503FB-ADE3-423E-8389-249A97F67385)
xcodebuild test -scheme "BeatRate Development" -project BeatRate.xcodeproj \
  -destination 'id=9CE503FB-ADE3-423E-8389-249A97F67385' -only-testing:<Target>
```

---

## PR 1 · Infrastruktura

### Task 2.1: `Core/IntrospectionKit` z repo

**Pliki:**
- USER: pakiet `Core/IntrospectionKit`; produkt i target `IntrospectionKit` bez zależności; test target `IntrospectionKitTests`; platformy `.iOS(.v27), .macOS(.v27)`, `.defaultIsolation(MainActor.self)`.
- Utwórz (kopia z `Core/Sources/IntrospectionKit/` w repo): `IntrospectionNode.swift`, `IntrospectionSession.swift`, `IntrospectionServer.swift`, `LineBuffer.swift`.
- Utwórz (kopia z `Core/Tests/IntrospectionKitTests/`): `IntrospectionSessionTests.swift`, `IntrospectionServerTests.swift`, `LineBufferTests.swift`.
- Zmień: `test` (pakiet na liście `PACKAGES`, katalog `Core/IntrospectionKit/Sources` w strażniku).

**Interfejsy:**
- Produkuje: `IntrospectionNode`, `IntrospectionProviding`, `IntrospectionInput`, `IntrospectionAction(_:perform:)`, `IntrospectionAction(_:input:perform:)`, `IntrospectionSession(root:)` z `handle(_:) -> String` oraz `IntrospectionServer(port:session:)` z `start()` (tylko DEBUG). API jest identyczne z repo.

- [ ] **Krok 1:** Po potwierdzeniu USER skopiuj pliki bez zmian API.
- [ ] **Krok 2:** `./test Core/IntrospectionKit`.
  Oczekiwane: 6 testów zielonych. Jeśli bez flag upcoming kompilator zgłosi izolację (`IntrospectionInput` z `nonisolated`, handler w `NWListener`), napraw to najmniejszą adnotacją (`nonisolated`, `@MainActor`) i zapisz Ruling.
- [ ] **Krok 3:** Build obu schematów: zielony.
- [ ] **Krok 4:** Commit `Copy IntrospectionKit from the Reflex reference`.

### Task 2.2: Fixtury i fałszywe krawędzie

**Pliki:**
- USER: pakiet `Tools/BeatRateCLI`.
  - Produkty: biblioteka `BeatRateFixtures`, a od 2.7 executable `beatrate-cli`.
  - Target `BeatRateFixtures` zależy od: Composition (produkt `Composition`), FirebaseService (`FirebaseService`, `FirebaseServiceFakes`), MusicKitService, SpotifyService, SwiftDataManager, CoreApp, Analytics, Models.
  - Test target `BeatRateFixturesTests`.
- Zmień: `Data/Services/FirebaseService/Package.swift`. Nowy target i produkt `FirebaseServiceFakes` (zależy od `FirebaseService`); `FirebaseServiceTests` zależy od niego.
- Przenieś: `FakeRealtimeDatabase` z `FirebaseServiceTestDoubles.swift` do `Sources/FirebaseServiceFakes/FakeRealtimeDatabase.swift`, jako `public actor`. `StubError` w nim zastąp `public struct FakeDatabaseError: Error`.
- Zmień: `Core/Analytics/Sources/Analytics/Logger/CrashLogger.swift` (`NoCrashBackend` i jego `init` stają się `public`).
- Zmień: `Data/Services/SwiftDataManager/Sources/SwiftDataManager/SwiftDataManager.swift` (dodaj `public static func inMemoryContainer() -> ModelContainer`; `inMemory()` z niego korzysta).
- Zmień: `Domain/Composition/Sources/Composition/Edges.swift` i `Graph.swift`. `Edges` dostaje `public var retryDelay: Duration` z parametrem `retryDelay: Duration = .seconds(2)` w `init`, a `Graph` ma `public let retryDelay: Duration`.
- Utwórz w `Tools/BeatRateCLI/Sources/BeatRateFixtures/`:
  - `Fixtures.swift`
  - `FakeFirebaseAuth.swift`
  - `FakeMusicKitService.swift`
  - `FakeKeychainBackend.swift`
  - `FakeSpotifyTransport.swift`
  - `FakeAnalyticsBackend.swift`
  - `NetworkGuard.swift` (kopia z repo, `InventoryCLI/NetworkGuard.swift`)
  - `Edges+Fixtures.swift`
- Testy: `Tools/BeatRateCLI/Tests/BeatRateFixturesTests/FixturesTests.swift`, `NetworkGuardTests.swift` (kopia 2 testów z repo) i `EdgesFixturesTests.swift`.

**Interfejsy:**
- Konsumuje: `RealtimeDatabase`, `FirebaseAuthProviding`, `MusicKitServiceProtocol`, `KeychainBackend`, `SpotifyTransport`, `AnalyticsBackend`, `Edges.init(...)`, `KeychainManager.saveAppleUserID(_:)`, `SwiftDataManager.setUserLoggedIn(userId:)`.
- Produkuje:
  - `public struct Fixtures` z polem `public let tree: [String: Any]` (scalone pliki) i metodami `public static func load(_ paths: [String]) throws -> Fixtures` oraz `func value(at path: String) -> Any?` (ścieżka `a/b/c`).
  - `public extension Edges { static func fixtures(_ fixtures: Fixtures) async throws -> Edges }`.
  - `public final class NetworkGuard: URLProtocol` z `violations`, `record(_:)`, `reset()` i `install()`.
  - `public actor FakeRealtimeDatabase` z `init(_ tree: DatabaseValue = .init(nil), failingReads: Set<String> = [], failingWrites: Set<String> = [], delay: Duration = .zero)`.

Format fixtury (spec, przykład 8): sekcje `db`, `music`, `device` i `timing`. Pliki scalamy głęboko, a przy tym samym liściu wygrywa późniejszy plik.

| Klucz | Znaczenie | Domyślnie |
| --- | --- | --- |
| `db` | drzewo RTDB (kształt eksportu z konsoli) | `{}` |
| `dbFailures.reads`, `dbFailures.writes` | ścieżki, których odczyt lub zapis rzuca `FakeDatabaseError` | `[]` |
| `dbDelayMs` | opóźnienie każdej operacji RTDB | `0` |
| `music.authorization` | status przed pytaniem: `notDetermined` / `denied` / `restricted` / `authorized` | `authorized` |
| `music.answer` | status po `requestMusicAuthorization()`, gdy był `notDetermined` | `authorized` |
| `music.subscription` | `hasSubscription` | `false` |
| `music.albums.<id>` | `AppleMusicAlbumData` jako JSON | brak = naruszenie |
| `device.firebaseUid` | `currentUserId()` w `FakeFirebaseAuth` | `null` |
| `device.keychain.appleUserID` | zapisane przez `KeychainManager.saveAppleUserID` | brak |
| `device.appleIDState` | `authorized` / `revoked` / `notFound` / `transferred` | `notFound` |
| `device.loggedInUserId` | `setUserLoggedIn(userId:)` w kontenerze w pamięci przed startem korzenia | brak |
| `device.defaults` | wartości wpisane do świeżego suite'a | `{}` |
| `timing.retryDelayMs` | `Edges.retryDelay` | `0` |

- [ ] **Krok 1: Testy, które padają**

```swift
// FixturesTests.swift
@Test func `later files win leaf by leaf and the db tree merges down to its leaves`() throws {
    // plik A: {"db":{"albums":{"1":{"title":"A","artist":"X"}}},"music":{"authorization":"denied"}}
    // plik B: {"db":{"albums":{"1":{"title":"B"},"2":{"title":"C"}}},"music":{"authorization":"authorized"}}
    let fixtures = try Fixtures.load([a, b])
    #expect(fixtures.value(at: "db/albums/1/title") as? String == "B")
    #expect(fixtures.value(at: "db/albums/1/artist") as? String == "X")
    #expect(fixtures.value(at: "db/albums/2/title") as? String == "C")
    #expect(fixtures.value(at: "music/authorization") as? String == "authorized")
}
@Test func `a file that is not a json object names the file`()   // błąd zawiera ścieżkę pliku

// EdgesFixturesTests.swift — Graph(edges: try await .fixtures(...)), bez UI
@Test func `the device section seeds keychain, login row, firebase session and defaults`() async throws
    // device.signedIn → getSplash.isUserLoggedIn() == true; analytics.consent == true;
    // players po hydrate: .appleMusic dla "u1"
@Test(arguments: [("authorized", true), ("revoked", false), ("notFound", false)])
func `the apple id state comes from the fixture`(state: String, valid: Bool) async throws
    // getSplash.areCredentialsValid() == valid dla device.signedIn z appleIDState = state
@Test func `music access starts undecided and the request answers from the fixture`() async throws
    // authorization notDetermined, answer denied → isAuthorizationDetermined false; request → .denied; potem true
@Test func `an album without a music fixture is a network violation`() async throws
    // fetchAlbumData(by: "missing") rzuca, NetworkGuard.violations == ["missing music fixture: album missing"]
@Test func `album data is refused while music access is not authorized`() async throws
    // authorization denied, album w fixturze → rzuca, violations puste
@Test func `a spotify request is a network violation`() async throws
@Test func `failing db paths throw and the delay holds each call back`() async throws
```

`FakeMusicKitService` jest `actor`, a `fetchArtistData`, `searchAlbums`, `search` i `fetchRecentlyPlayedAlbums` zgłaszają naruszenie `"missing music fixture: <metoda>"`. Testy `NetworkGuard` są `.serialized`, z komentarzem: `NetworkGuard` jest globalny na proces.

- [ ] **Krok 2:** `./test Tools/BeatRateCLI`. Oczekiwane: FAIL, bo nie ma `Fixtures`.
- [ ] **Krok 3:** Zaimplementuj pliki z listy.
  - `Edges.fixtures` składa krawędzie: `FakeRealtimeDatabase(tree: db, failingReads:, failingWrites:, delay:)`, `FakeFirebaseAuth(uid:)`, `FakeMusicKitService(music)`, `FakeSpotifyTransport()`, `spotifyPresenter: { nil }`, `FakeKeychainBackend()`, `appleIDCredentialState` z `device.appleIDState`, suite z `device.defaults`, `SwiftDataManager.inMemoryContainer()`, `FakeAnalyticsBackend()`, `NoCrashBackend()` i `retryDelay`.
  - Potem seeding: `KeychainManager(backend:).saveAppleUserID`, a do tego `SwiftDataManager(container:appleUserIDStore:).setUserLoggedIn` na tym samym kontenerze.
  - `FakeKeychainBackend` to słownik `kSecAttrAccount → Data` za `Mutex`.
- [ ] **Krok 4:** `./test Tools/BeatRateCLI Data/Services/FirebaseService Data/Services/SwiftDataManager Core/Analytics Domain/Composition`. Oczekiwane: zielone; FirebaseService ma tyle testów co przed przeniesieniem fake'a.
- [ ] **Krok 5:** Commit `Load fixtures into fake edges for a headless host`.

### Task 2.3: SDK podróży i `./test` z Node

**Pliki:**
- Utwórz: `behavior/sdk.mjs` (kopia z repo). Zmiany: `CLI = ../.build/logic/debug/beatrate-cli`, a w komunikatach `inventory-cli` → `beatrate-cli`.
- Utwórz: `behavior/sdk.test.mjs` (kopia z repo, bez zmian).
- Utwórz: `behavior/fixtures/` z plikami (prawdziwe dane z jednej sekcji produkcyjnej; `title` i `artist` w `db` i `music` muszą być równe):
  - `device.guest.json` (pusty `device`);
  - `device.signedIn.json` (spec, przykład 8, z `appleIDState: "authorized"`);
  - `catalog.discovery.json` (spec, przykład 8);
  - `music.undecided.json`;
  - `music.refused.json`;
  - `apple.revoked.json`;
  - `db.sectionsFail.json`;
  - `timing.slowRetry.json` (`retryDelayMs: 300`);
  - `consent.given.json`.
- Zmień: `test`. Po pakietach i strażniku idzie `swift build --package-path Tools/BeatRateCLI --scratch-path .build/logic --product beatrate-cli`, a w 2.7 `node --test 'behavior/*.test.mjs'`. W tym zadaniu Node uruchamia tylko `behavior/sdk.test.mjs`. Krok Node działa także wtedy, gdy `./test` dostał listę pakietów. Do listy strażnika dochodzą katalogi `Presentation/*/Sources` i `Tools/*/Sources`, z wyjątkiem `/Sources/[A-Za-z]*(Live|UI)/`.

- [ ] **Krok 1:** `node --test behavior/sdk.test.mjs`. Oczekiwane: 1 test zielony (tylko fałszywe CLI, prawdziwe nie jest potrzebne).
- [ ] **Krok 2:** `./test Core/Models`. Oczekiwane: testy Models, strażnik i test SDK zielone, kod wyjścia 0.
- [ ] **Krok 3:** Commit `Run behavior tests from ./test`. Otwórz PR 1 do `feature/reflex-phase-2`.

---

## PR 2 · Splash w kształcie Reflex

### Task 2.4: `SplashViewModel` zamiast `SplashDataModel`

Zmierz koszt ekranu: zapisz w ledgerze czas startu i końca zadania, a w kroku 7 linie (G2).

**Pliki:**
- Zmień: `Presentation/Splash/Package.swift`.
  - Platformy `.iOS(.v27), .macOS(.v27)`.
  - Target `Splash` (logika): Composition, SplashUseCases, Analytics, CoreApp, Models, IntrospectionKit.
  - Nowy target `SplashUI`: `Splash`, a do tego CoreUI i Onboarding z `.when(platforms: [.iOS])`.
  - Produkty `Splash` i `SplashUI`. Testy zależą od `Splash`.
  - Zasoby (`Resources`, String Catalog) przechodzą do `SplashUI`.
- Zmień: `BeatRate.xcodeproj/project.pbxproj`. Oba targety aplikacji linkują `SplashUI`; `Splash` przychodzi z nim.
- Utwórz: `Sources/Splash/ViewModel.swift` (kopia z repo), `Sources/Splash/SplashViewModel.swift` i `Sources/Splash/SplashViewModel+Introspection.swift`.
- Przenieś: `SplashView.swift` i `SplashContentView.swift` do `Sources/SplashUI/`, w `#if os(iOS)`.
- Usuń: `SplashDataModel.swift`, `Tests/SplashTests/SplashDataModelTests.swift` (decyzja 19, po przeniesieniu przypadków).
- Utwórz: `Tests/SplashTests/SplashViewModelTests.swift`; zmień `SplashTestDoubles.swift`.
- Zmień: `App/AppDelegate/AppDataModel.swift` i `AppView.swift` (`AppDataModel` trzyma i odnawia `SplashViewModel`).
- Zmień: `test` (`Presentation/Splash` na liście pakietów).

**Interfejsy:**
- Konsumuje: `GetSplashUseCaseProtocol`, `MusicPlayerManager.current`, `AnalyticsManager.log(_:)`, `Graph.retryDelay` (2.2), `IntrospectionKit` (2.1).
- Produkuje:

```swift
@Observable public final class SplashViewModel: ViewModel {
    public struct State: Encodable, Equatable {
        public enum Phase: String, Encodable { case loading, musicExplainer, finished }
        public enum RetryReason: String, Encodable { case noData, connectionError }
        public struct Retry: Encodable, Equatable { public var attempt: Int; public var of: Int; public var reason: RetryReason }
        public var phase = Phase.loading
        public var retry: Retry?
    }
    public enum Action { case continuePastExplainer }
    enum Message {
        case viewAction(Action)
        case credentialsChecked(isValid: Bool)
        case musicAccessChecked(isDetermined: Bool)
        case cacheChecked(isUsable: Bool)
        case fetched([HomeSection])
        case fetchFailed
        case cached
        case retryDue
    }
    public internal(set) var state: State
    var pending: Task<Void, Never>?     // ponytail: uchwyt ostatniego efektu (M5); testy na niego czekają
    init(getSplash: any GetSplashUseCaseProtocol, players: MusicPlayerManager, analytics: AnalyticsManager,
         retryDelay: Duration, maxRetries: Int = 3, onFinish: @escaping () -> Void)
    public convenience init(graph: Graph, onFinish: @escaping () -> Void)
    public func send(action: Action)
}
```

Przejścia w `update` (decyzje należą do `update`, efekty to `Task` przypisany do `pending`):

| Wiadomość | Zmiana stanu | Efekt |
| --- | --- | --- |
| `init` | `phase = .loading`; log `.screenView(.splash)` | zalogowany ? `areCredentialsValid()` : `true` → `.credentialsChecked` |
| `.credentialsChecked(false)` | `finish` | — |
| `.credentialsChecked(true)` | — | `isMusicKitAuthorizationDetermined()` → `.musicAccessChecked` |
| `.musicAccessChecked(false)` | `phase = .musicExplainer`; log `.screenView(.musicLibraryPermission)` | — |
| `.musicAccessChecked(true)` | — | `prepare()` → `.cacheChecked` |
| `.viewAction(.continuePastExplainer)` | poza `.musicExplainer`: nic; inaczej `phase = .loading`; log `.permissionContinueTap` | `prepare()` → `.cacheChecked` |
| `.cacheChecked(true)` | `finish` | — |
| `.cacheChecked(false)` | — | `fetchHomeSections()` → `.fetched` / `.fetchFailed` |
| `.fetched([])` | `retryOrFinish(.noData)` | |
| `.fetched(sections)` | — | `cacheSections` (błąd ignorowany) → `.cached` |
| `.cached` | `finish` | — |
| `.fetchFailed` | `retryOrFinish(.connectionError)`; przy ostatnim `CrashLogger.report("SplashFetch", …)` | |
| `.retryDue` | — | `fetchHomeSections()` |

- `finish` ustawia `phase = .finished`, `retry = nil` i woła `onFinish()`. Wiadomości po `.finished` nie robią nic.
- `retryOrFinish(reason)`: dopóki `(retry?.attempt ?? 0) < maxRetries`, ustawia `retry = Retry(attempt: +1, of: maxRetries, reason:)` i startuje efekt `sleep(retryDelay)` → `.retryDue`. Po wyczerpaniu prób woła `finish`.
- `prepare()` wykonuje bez zmian kroki 2b–4 ze starego `continueAfterMusicKitGate`: autoryzacja z `CrashLogger.report("Connect.appleMusic", …)` przy odmowie, `hydrateMainMusicPlayer`, weryfikacja Spotify z `refreshSpotifyPremium` i sprawdzenie cache. Logi `Logger.splash` zostają.

Węzeł (`+Introspection.swift`) to jeden typ z nazwą zależną od fazy: `Splash` dla `.loading` i `.finished`, `MusicExplainer` dla `.musicExplainer`. Stan to `viewModel.state`. Akcja `Continue` jest zawsze na liście i wysyła `.continuePastExplainer`; poza explainerem `update` ją ignoruje.

Widok: `SplashView(viewModel:)` czyta `state.retry` (tekst przez istniejące klucze `splashRetryingNoData` / `splashRetryingConnection`), a explainer pokazuje przy `phase == .musicExplainer`. CTA wysyła `.continuePastExplainer`. Nie ma `.task` ani `onAppear`.

`AppDataModel`:
- `private(set) var splash: SplashViewModel?` powstaje w `init` przez `SplashViewModel(graph: .current) { [weak self] in self?.splashFinished() }`, a po zalogowaniu (false → true) jest tworzony od nowa;
- `showingSplash` zostaje, a `AppView` animuje zmianę `.animation(AppAnimation.smooth, value: dataModel.rootScreen)`.

- [ ] **Krok 1: Testy, które padają.** Przenieś 14 przypadków z `SplashDataModelTests` (nazwy bez zmian, asercje na `state` i stubie) i dodaj:

```swift
@Test func `continue outside the explainer changes nothing`() {
    let viewModel = SplashViewModel.make(splash: StubGetSplashUseCase())
    var state = viewModel.state
    state.phase = .loading
    viewModel.update(state: &state, message: .viewAction(.continuePastExplainer))
    #expect(state == SplashViewModel.State(phase: .loading, retry: nil))
}
@Test(arguments: [SplashViewModel.Message.fetchFailed, .fetched([])])
func `each failure counts one attempt until the third one finishes`(failure: SplashViewModel.Message) {
    // attempt 1, 2, 3 → retry.of == 3; czwarta → phase == .finished, onFinish wołane raz
}
@Test func `messages after finishing are ignored`()                 // .cached po .finished → onFinish dalej 1 raz
@Test func `the node is named after the phase and always lists Continue`()
```

`SplashTestDoubles.swift` dostaje:
- `SplashViewModel.make(splash:players:retryDelay: .zero, onFinish:)`;
- `func settled() async`, które czeka na `pending`, dopóki zmienia się po każdym `await`.

- [ ] **Krok 2:** `./test Presentation/Splash`. Oczekiwane: FAIL, bo nie ma `SplashViewModel`.
- [ ] **Krok 3:** Zaimplementuj według tabel. Przenieś widoki do `SplashUI`.
- [ ] **Krok 4:** `./test Presentation/Splash`. Oczekiwane: wszystkie testy zielone (≥ 18), a pokrycie `Sources/Splash/` 100%.
- [ ] **Krok 5:** Build obu schematów i plan Development na symulatorze: zielone.
- [ ] **Krok 6:** Smoke na symulatorze.
  - Start po usunięciu aplikacji pokazuje explainer. Continue wywołuje systemowy prompt, a potem pojawiają się zakładki z alertem zgody.
  - Restart: splash i zakładki.
  - Jeden log `Requesting MusicKit authorization` na start (Review Focus 1).
- [ ] **Krok 7:** Ledger: koszt ekranu.
  - Czas zadania.
  - `git diff --stat` dla `Presentation/Splash`: linie ViewModelu i węzła oraz linie testów wobec usuniętego DataModelu.
  - Ekstrapolacja na 12 DataModeli.
- [ ] **Krok 8:** Commit `Run the splash as a Reflex view model`. Otwórz PR 2.

---

## PR 3 · Korzeń, host iOS, CLI i podróże

### Task 2.5: `Presentation/AppRoot`: `BeatRateApp` i `AppNavigator`

**Pliki:**
- USER: pakiet `Presentation/AppRoot`.
  - Produkty `AppRoot` i `AppRootUI`.
  - Target `AppRoot`: Composition, Splash, AppUseCases, CoreApp, Analytics, Models, IntrospectionKit.
  - Target `AppRootUI`: `AppRoot`, a z `.when(platforms: [.iOS])`: SplashUI, TabBar, Login, Onboarding, CoreUI.
  - Test target `AppRootTests` (od `AppRoot`).
  - Platformy `.iOS(.v27), .macOS(.v27)`.
- Utwórz w `Sources/AppRoot/`: `ViewModel.swift` (kopia), `BeatRateApp.swift`, `BeatRateApp+Introspection.swift`, `AppNavigator.swift` i `AppNavigator+Introspection.swift`.
- Zmień: `Core/CoreApp/Sources/CoreApp/SessionManager.swift` (`LoginPromptReason: String, Encodable`).
- Testy: `Tests/AppRootTests/AppNavigatorTests.swift`, `AppRootTestDoubles.swift`.
- Zmień: `test` (`Presentation/AppRoot`).

**Interfejsy:**
- Konsumuje: `SplashViewModel(graph:onFinish:)` (2.4), `GetAppUseCaseProtocol`, `SessionManager`, `MusicPlayerManager`, `AnalyticsManager`, `CrashLogger`, `Graph`.
- Produkuje:

```swift
public final class BeatRateApp: IntrospectionProviding {
    public let navigator: AppNavigator
    public init(edges: Edges)          // Graph(edges:), Graph.current = graph, navigator = AppNavigator(graph:)
}

@Observable public final class AppNavigator: ViewModel {
    public struct State: Encodable, Equatable {
        public enum Phase: String, Encodable { case splash, playerPicker, tabs }
        public var phase = Phase.splash
        public var isLoggedIn = false
        public var hasPlayer: Bool
        public var userId: String?
        public var isAskingAnalyticsConsent: Bool
        public var analyticsConsent: Bool?
        public var loginPrompt: LoginPromptReason?
    }
    public enum Action { case allowAnalytics, denyAnalytics, dismissLoginPrompt, selectedTab(String) }
    enum Message {
        case viewAction(Action)
        case initialLoginStatus(Bool)
        case loginStateChanged(Bool)
        case splashFinished
        case userLoaded(User?)
        case playerChanged(hasPlayer: Bool)
        case loginPromptChanged(LoginPromptReason?)
    }
    public internal(set) var state: State
    public private(set) var splash: SplashViewModel?      // podrzędny ekran, jak `home` w repo
    public let graph: Graph                                // ponytail: stare widoki zakładek czytają Graph.current
    init(graph: Graph, makeSplash: @escaping (@escaping () -> Void) -> SplashViewModel)
    public convenience init(graph: Graph)
    public func send(action: Action)
}
```

Przejścia przenoszą `AppDataModel` 1:1:
- Faza: `isShowingSplash` → `.splash`; `isLoggedIn && !hasPlayer` → `.playerPicker`; inaczej `.tabs`.
- `.loginStateChanged(true)` po `false`: nowy `splash` (Review Focus 1) i ponowna identyfikacja użytkownika.
- `.loginStateChanged(false)`: `analytics.setUserId(nil)` i `crashLogger.setUserIdentifier(nil)`.
- Każda zmiana logowania woła `session.update(isLoggedIn:)`.
- `.allowAnalytics` / `.denyAnalytics`: `analytics.setConsent`; przy zgodzie identyfikacja (`setUserId`, jak w `AppDataModel.setUserId`).
- `.dismissLoginPrompt`: `session.isPresentingLoginPrompt = false`.
- `.selectedTab(name)`: log `.tabSelected(tab:)`, czyli dzisiejsze `trackTabSelected`.
- Efekty z `init`:
  - `isUserLoggedIn()` → `.initialLoginStatus`;
  - pętla `observeLoginState()` → `.loginStateChanged`;
  - `Observations { players.current != nil }` → `.playerChanged`;
  - `Observations { session.isPresentingLoginPrompt ? session.loginPromptReason : nil }` → `.loginPromptChanged`;
  - przy każdym wejściu w splash `getCurrentUser()` → `.userLoaded`.

Węzły:
- `App`: stan nawigatora, bez własnych akcji. Dziecko:
  - `LoginPrompt`, gdy `loginPrompt != nil`; stan `{reason}`, pożycza akcję `dismiss`;
  - inaczej `AnalyticsConsent`, gdy `phase == .tabs && isAskingAnalyticsConsent`; akcje `AllowAnalytics` i `DenyAnalytics`;
  - inaczej, według fazy: węzeł `splash`, liść `PlayerPicker` albo liść `Tabs`, które mają stan `{}` i nie mają akcji.
- Akcji `selectedTab` węzeł nie pokazuje. Zakładki w Core to faza 3, a do tego czasu zakładkę wybiera palec w starym `TabBarView`.

- [ ] **Krok 1: Testy, które padają** (`AppRootTestDoubles`: stuby `GetAppUseCaseProtocol` z kontrolowanym `AsyncStream`, `Graph` ze stubów krawędzi na wzór `CompositionTestDoubles.swift`, bo `BeatRateFixtures` w testach AppRoot dałoby cykl pakietów AppRoot ↔ BeatRateCLI; `func eventually(_ condition: () -> Bool) async` z limitem 1 s):

```swift
@Test func `a guest who finishes the splash lands on the tabs and is asked for consent once`() async
@Test func `a signed-in user without a player goes to the picker and on to the tabs once one is set`() async
@Test func `a second login starts a fresh splash and the first one is gone`() async   // weak ref do pierwszego == nil
@Test func `logging out clears the analytics and crash user`() async
@Test(arguments: [true, false]) func `answering the consent alert stores it and stops asking`(granted: Bool)
@Test func `granting consent identifies a signed-in user`() async
@Test func `the login prompt follows the session and dismiss closes it`() async
@Test func `the node shows the prompt over consent and consent over the tabs`()
@Test func `the root's node is the navigator's`()
```

- [ ] **Krok 2:** `./test Presentation/AppRoot`. Oczekiwane: FAIL.
- [ ] **Krok 3:** Zaimplementuj.
- [ ] **Krok 4:** `./test Presentation/AppRoot Core/CoreApp`. Oczekiwane: zielone, a pokrycie `Sources/AppRoot/` 100%.
- [ ] **Krok 5:** Commit `Move the app's root and launch flow into AppRoot`.

### Task 2.6: Host iOS: `BeatRateMain`, `RootView`, serwer :7777

**Pliki:**
- Utwórz: `Presentation/AppRoot/Sources/AppRootUI/RootView.swift` (`#if os(iOS)`). Ciało dzisiejszego `AppView`:
  - `switch navigator.state.phase`: `SplashView(viewModel: navigator.splash!)`, stare `MusicPlayerPickerView(mode: .onboarding)` albo stare `TabBarView`.
  - Zaznaczenie zakładki (`TabBarScreen?`) to `@State` widoku, a `onChange` wysyła `.selectedTab`.
  - Alert zgody na bindingu `state.isAskingAnalyticsConsent`, z akcjami.
  - Arkusz `LoginPromptView(reason:)` na bindingu `state.loginPrompt != nil`, a jego `set(false)` wysyła `.dismissLoginPrompt`.
- Zmień: `App/AppDelegate/BeatRateApp.swift` → `App/AppDelegate/BeatRateMain.swift` (`@main struct BeatRateMain`). Wzór to spec (przykład 7) i `Mobile/ReflexArchitectureApp.swift` w repo: `@State private var app = BeatRateApp(edges: .live())`, a w `#if DEBUG` serwer na porcie 7777 startowany w `.task`.
- Zmień: `Domain/Composition/Sources/CompositionLive/Edges+Live.swift`. Pierwsze linie `live()`: `FirebaseApp.configure()`, `Database.database(url:)`, `isPersistenceEnabled = true`, `persistenceCacheSizeBytes = 10 * 1024 * 1024`. Zależność `FirebaseCore` i `FirebaseDatabase` z `.when(platforms: [.iOS])`.
- Zmień: `App/AppDelegate/AppDelegate.swift`. Zostaje tylko `setAnalyticsEnabled(consent == true)` i `CrashLogger.shared.configure()`; `Graph.current` ustawia teraz korzeń.
- Usuń: `App/AppDelegate/AppView.swift`, `AppDataModel.swift`.
- Zmień: `project.pbxproj`. Oba targety linkują `AppRootUI` i `IntrospectionKit`, a nie linkują już `TabBar`, `Login`, `Splash` ani `SplashUI` bezpośrednio (`AppRootUI` je przynosi). Zmień też nazwę pliku `@main`.

- [ ] **Krok 1:** Build obu schematów: zielony.
- [ ] **Krok 2:** Smoke na symulatorze (iPhone Duo): start po usunięciu aplikacji → explainer → Continue → zakładki z alertem zgody; Home ma sekcje (Review Focus 2); restart; arkusz logowania z Account → zamknięcie gestem.
- [ ] **Krok 3:** `printf 'ls\n' | nc -w 1 127.0.0.1 7777`. Oczekiwane: `App` albo `Tabs` ze stanem. Potem `printf 'do DenyAnalytics\nls\n' | nc -w 1 127.0.0.1 7777` na świeżej instalacji: alert znika na ekranie.
- [ ] **Krok 4:** Build Release (`-configuration Release -destination 'generic/platform=iOS Simulator'`), potem `strings "<…>/BeatRate.app/BeatRate" | grep -c IntrospectionServer`. Oczekiwane: `0` (Review Focus 4).
- [ ] **Krok 5:** Commit `Host the root in the iOS app with a debug introspection server`.

### Task 2.7: `beatrate-cli`, podróże startu, dokumentacja, pomiar G2

**Pliki:**
- Zmień: `Tools/BeatRateCLI/Package.swift`. Executable `beatrate-cli` (target `BeatRateCLI`): AppRoot, BeatRateFixtures, IntrospectionKit.
- Utwórz: `Tools/BeatRateCLI/Sources/BeatRateCLI/CLI.swift`. Kopia `InventoryCLI/CLI.swift` z repo; różnice:
  - `Fixtures.load`, `NetworkGuard.install()` i `BeatRateApp(edges: try await .fixtures(fixtures))`;
  - użycie `beatrate-cli --fixtures <file.json>...`;
  - kody wyjścia 64, 66 i 3 jak w repo.
- Utwórz: `cli` (kopia z repo, `chmod +x`). Build to `swift build -q --package-path Tools/BeatRateCLI --scratch-path .build/logic --product beatrate-cli`, a domyślne fixtury `device.guest.json catalog.discovery.json`.
- Utwórz: `behavior/launch.test.mjs`.
- Zmień: `test` (`node --test 'behavior/*.test.mjs'`).
- Dokumentacja (spec, „Zmiany w dokumentacji”, faza 2):
  - `CLAUDE.md`: Build & Run (`./cli`, `nc localhost 7777`), przepis „Adding a New Feature Screen” w 6 krokach ze specu, Unit Tests (testy przejść `update`, no-opy jednostkowo, `Fake…` dla krawędzi CLI) i Verifying (`./test`);
  - `.claude/skills/reflex/SKILL.md`: adaptacja skilla z repo (uruchamianie, reguły węzła, fixtury według tabeli z 2.2, dodawanie ekranu i podróży, sterowanie na żywo);
  - `AGENTS.md`: skill `reflex` w tabeli;
  - `README.md`: sekcja „Aplikacja bez UI”.

**Interfejsy:**
- Konsumuje: `Fixtures`, `Edges.fixtures` i `NetworkGuard` (2.2), `BeatRateApp` (2.5), `createBehaviorSession` i `fixture` (2.3).

- [ ] **Krok 1: Podróże, które padają** (`behavior/launch.test.mjs`, spec: przykład 9 i punkty parity 1, 2, 3, 5, 6, 19):

```js
test('a first-time guest sees the explainer, continues, and is asked for consent on the tabs', …)
  // fixtures: device.guest, catalog.discovery, music.undecided
  // precondition MusicExplainer → do Continue → AnalyticsConsent → do AllowAnalytics → Tabs, state App.analyticsConsent true
test('refused music access still enters the app', …)        // + music.refused → Tabs (parity 2)
test('revoked Apple ID logs out completely and enters as a guest', …)
  // device.signedIn, apple.revoked, consent.given, catalog.discovery → Tabs; App.isLoggedIn false (parity 5)
test('three failed fetches still enter the app', …)
  // device.guest, consent.given, db.sectionsFail, timing.slowRetry → Splash z retry.attempt 1 → Tabs (parity 3)
test('a lost login row is rebuilt from the keychain and the firebase session', …)
  // device.signedIn bez loggedInUserId, consent.given, catalog.discovery → Tabs; App.isLoggedIn true (parity 6)
test('a signed-in user without a player is sent to the picker', …)   // device.signedIn bez defaults gracza → PlayerPicker
test('a returning guest with consent is not asked again', …)         // consent.given → Tabs bez AnalyticsConsent (parity 1, 19)
test('an album without a music fixture ends the cli with code 3', …) // catalog bez music.albums → rejects /network violation/
```

Każdy test zamyka sesję w `t.after(() => session.close())`. Oczekiwanie nie może być prawdziwe przed akcją (reguła z repo).

- [ ] **Krok 2:** `./test Tools/BeatRateCLI`. Oczekiwane: podróże FAIL, bo nie ma `beatrate-cli`.
- [ ] **Krok 3:** Zaimplementuj `CLI.swift` i `cli`.
- [ ] **Krok 4:** `./test`. Oczekiwane: wszystkie pakiety, strażnik, 9 testów Node (8 podróży i SDK) zielone, kod wyjścia 0.
- [ ] **Krok 5:** `printf 'ls\ndo Continue\nls\n' | ./cli behavior/fixtures/device.guest.json behavior/fixtures/catalog.discovery.json behavior/fixtures/music.undecided.json`. Oczekiwane: kolejno `MusicExplainer`, `ok`, `AnalyticsConsent`.
- [ ] **Krok 6: Pomiar G2.** Dopisz jedną linię komentarza w `SplashViewModel.swift`, potem `time ./test Presentation/Splash`. Oczekiwane: ≤ 30 s. Zapisz w ledgerze, razem z czasem jednej podróży z wyjścia `node --test` (cel < 1 s). Wycofaj komentarz.
- [ ] **Krok 7:** Commit `Drive the launch headlessly with beatrate-cli and behavior tests`. Otwórz PR 3.

---

## Bramka G2 (go/no-go)

Po merge'u PR 3 zapisz w sekcji „Wyniki fazy 2” tego planu:

| Kryterium | Próg | Źródło |
| --- | --- | --- |
| Podróże startu bez UI | 8/8 zielone | 2.7 krok 4 |
| Te same akcje przez `nc` | ekran podąża | 2.6 krok 3 |
| `./test` po zmianie jednego pliku | ≤ 30 s | 2.7 krok 6 |
| Koszt ekranu | czas i linie Splash, ekstrapolacja × 12 | 2.4 krok 7 |
| Regresje w testach Swift | 0; liczba `@Test` ≥ przed fazą (tylko zastąpione) | `./test` + plan Development |
| QA palcem | start gościa, odmowa MusicKit, logowanie i restart na iPhonie | przed PR-em fazy |

Decyzję GO/NO-GO podejmuje użytkownik na podstawie tej tabeli.

## Wyniki fazy 2

_(do uzupełnienia)_
