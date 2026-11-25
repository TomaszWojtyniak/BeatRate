# BeatRate → Reflex, fazy 0–1: plan implementacji

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Cel:** Faza 0 sprawdza założenia planu (spike'i, nonce, pomiar bazowy). Faza 1 sprawia, że cała logika buduje się i testuje na macOS bez SDK, a obiekty powstają raz, w jednym `Graph`. Zachowanie aplikacji się nie zmienia.

**Architektura:** Najpierw jeden composition root (`Domain/Composition`, `Graph`) zastępuje 15 z 16 singletonów. Potem kod SDK przechodzi do targetów `…Live`, obudowanych `#if os(iOS)` i z zależnościami SDK tylko dla iOS. Na końcu `Edges` oddaje hostowi wybór krawędzi, a wszystkie pakiety logiki dostają macOS i wspólny skrypt `./test`.

**Stos:** Swift 6.4.2, Xcode 27.2, SwiftPM (`swift-tools-version: 6.4`), Swift Testing, Firebase iOS SDK ≥ 11.13 (Auth, Database, Analytics, Crashlytics), MusicKit, SwiftData, AuthenticationServices.

**Spec:** `docs/superpowers/specs/2026-11-24-reflex-migration-design.md`, sekcje „Plan działania” (fazy 0–1), „Testy i weryfikacja” i „Decyzje” (pytania 1–24, M1–M9).

## Global Constraints

- iOS 27 zostaje wszędzie. `.macOS(.v27)` dostają tylko pakiety logiki: Core/Models, Core/CoreApp, Core/Analytics, Data/*, Domain/*. Presentation/* i Core/CoreUI zostają tylko na iOS.
- Każdy pakiet zachowuje `.defaultIsolation(MainActor.self)`. Nie włączamy `NonisolatedNonsendingByDefault` ani `InferIsolatedConformances` (decyzja 15).
- Zero zmian zachowania. Zostają te same nazwy zdarzeń (`screen_view`, `search`, `sign_up`, `login`, …), ścieżki RTDB, klucze UserDefaults (`analyticsConsent`, `mainMusicPlayer.<uid>`) i magazyn SwiftData. Kolejność kroków logowania i wylogowania też się nie zmienia.
- Firebase*, MusicKit i UIKit wolno importować tylko w targetach `…Live` i w `App/`. Każdy plik `…Live`, także testowy, jest w `#if os(iOS)`. Zależności tych targetów od SDK mają `condition: .when(platforms: [.iOS])`.
- AuthenticationServices, Security, CryptoKit, SwiftData, Observation i OSLog są dozwolone w logice, bo budują się na macOS.
- Jedynym singletonem po fazie 1 jest `CrashLogger.shared`. Jego 113 statycznych wywołań zostaje bez zmian.
- Każdy obiekt ze stanem ma jedną instancję na proces, utworzoną w `Graph`. `Graph.current` czytają tylko stare DataModele, `TabBarView` i `AppDelegate`.
- Testy piszemy w Swift Testing, z nazwami-zdaniami w backtickach. Dublery `Stub…` i `Fake…` trzymamy w `<Package>TestDoubles.swift`. Bez sieci, prawdziwego Keychain, `UserDefaults.standard` i SwiftData na dysku. Przed pisaniem testów załaduj skill `swift-testing-expert` (CLAUDE.md).
- Po każdym zadaniu: Xcode MCP `BuildProject` dla obu schematów, a do tego testy pakietów, których zadanie dotyka. Zapasowo `xcodebuild … -quiet build`, sprawdzając kod wyjścia.
- Wymagamy 100% pokrycia linii logiki w dotkniętych modułach. Wyjątki są tylko dla cienkich adapterów SDK w `…Live` i dla no-opów; każdy wyjątek nazwij w opisie PR-a.
- Pierwsze `swift test` w pakiecie zależnym od `firebase-ios-sdk` pobiera SDK (kilka minut). SDK nie buduje się na macOS dzięki `.when(platforms: [.iOS])`.

## Review Focus

1. **Zimny start:** `Graph.current` musi zostać ustawiony w `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, zanim SwiftUI utworzy `AppView` i jego `AppDataModel`. Inaczej aplikacja pada przy starcie. Pilnują tego kroki smoke w zadaniach 1.2 i 1.8 (start po usunięciu aplikacji).
2. **Zgoda na analitykę:** `AnalyticsManager` z `Graph` musi czytać `UserDefaults.standard` (klucz `analyticsConsent`). Inny `UserDefaults` oznacza ponowny alert zgody i utratę wyboru. Pilnują tego test w zadaniu 1.7 i `defaults: .standard` w `Edges.live()`.
3. **Magazyn SwiftData na dysku:** `Edges.live()` musi użyć `SwiftDataManager.makeContainer()`. Kontener w pamięci zgubiłby wiersz `User`, więc zalogowany użytkownik po restarcie byłby gościem. Pilnuje tego krok smoke w zadaniu 1.8 (zabicie aplikacji po zalogowaniu i ponowny start).
4. **Crashlytics:** `CrashLogger.shared.use(FirebaseCrashBackend())` (w `Graph`) musi poprzedzać `CrashLogger.shared.configure()` w `AppDelegate`. Odwrotna kolejność po cichu wyłącza zbieranie crashy. Pilnują tego test `use` w zadaniu 1.3 i kolejność wywołań w `AppDelegate` sprawdzana w review.
5. **Arkusz OAuth Spotify:** `SpotifyWebAuthSession.make()` czyta `UIApplication.shared.connectedScenes`, więc w `Graph` i w `Edges.live()` musi być wołane jako `{ @MainActor in SpotifyWebAuthSession.make() }`. Pilnują tego kompilator (`make()` jest `@MainActor`) i krok smoke w zadaniu 1.8 (połączenie Spotify z wyboru odtwarzacza).

## Odstępstwa od specu

- **Szew Spotify:** zamiast nowego `WebAuthenticating` używamy istniejącego protokołu `SpotifyAuthorizationPresenter` i parametru `makePresenter` w `SpotifySession`.
- **Szew Firebase Auth:** wprowadzamy cienki `FirebaseAuthProviding`, zamiast podmieniać cały `AuthFirebaseServiceProtocol`. Logika `AuthFirebaseService` (zapis w Keychain z wycofaniem, profil, analityka) zostaje w logice i dostaje instancje z `Graph`. Inaczej adapter potrzebowałby własnego `AnalyticsManager`, czyli drugiego grafu.
- **`AppleSignInCredential`:** zostaje w logice razem z `init?(_ authorization:)`, bo AuthenticationServices buduje się na macOS. Przeniesienie zmusiłoby Login i Settings do zależności od targetu `…Live`.
- **`Edges.live()`:** trafia do targetu `CompositionLive` w pakiecie Composition, a nie do `App/`. Aplikacja linkuje wtedy jeden produkt `Composition`.
- **`FirebaseApp.configure()`:** w fazie 1 zostaje w `AppDelegate`. Do `Edges.live()` przejdzie w fazie 2, gdy korzeń będzie powstawał w `@State`.
- **`Edges`:** na razie bez `retryDelay` i `searchDebounce`. Dojdą w fazie 2 razem z ViewModelami, które ich używają.
- **Targety `…Live` w tym samym pakiecie:** `swift test` buduje wszystkie targety pakietu, także te, od których testy nie zależą (eksperyment z 25.11.2026). Dlatego każdy plik `…Live` jest w `#if os(iOS)`. Ten sam koszt dotknie targetów `…UI` z decyzji 5; wracamy do tego przed fazą 2.

## Gałęzie i PR-y

| PR | Gałąź (od `development`) | Zadania |
| --- | --- | --- |
| PR 0 | `task/reflex-phase-0` | spec, ten plan, wyniki 0.1–0.3 |
| PR 0b (warunkowy) | `task/login-nonce` | 0.4 |
| PR 1 | `task/reflex-composition-root` | 1.1–1.2 |
| PR 2 | `task/reflex-live-targets` | 1.3–1.7 |
| PR 3 | `task/reflex-macos-tests` | 1.8 |

Wspólne komendy:

```bash
# Build zapasowy, gdy Xcode MCP nie odpowiada; liczy się kod wyjścia, nie wyjście
xcodebuild -scheme "BeatRate Development" -project BeatRate.xcodeproj -destination 'generic/platform=iOS Simulator' -quiet build

# Testy jednego targetu na symulatorze
xcodebuild test -scheme "BeatRate Development" -project BeatRate.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone Duo' -only-testing:<Target>

# Pokrycie pakietu logiki na macOS
swift test --package-path <pkg> --enable-code-coverage && \
jq -r '.data[0].files[] | select(.filename | contains("/Sources/")) | "\(.summary.lines.percent | floor)% \(.filename)"' \
  "$(swift test --package-path <pkg> --show-codecov-path)"
```

---

## Faza 0

### Task 0.1: Spike A — łańcuch logiki na macOS bez Firebase

Kod ze spike'a wyrzucamy; zostaje tylko wiedza. Limit czasu: 2 h.

**Pliki:** worktree `../BeatRate-spike-a` na usuwanej gałęzi `spike/reflex-macos`; wyniki trafiają do sekcji „Wyniki fazy 0” tego planu na gałęzi `task/reflex-phase-0`.

- [ ] **Krok 1:** Utwórz `task/reflex-phase-0` z `development`, dodaj spec i ten plan, commit `Add Reflex migration spec and phase 0–1 plan`.
- [ ] **Krok 2:** `git worktree add ../BeatRate-spike-a -b spike/reflex-macos development`.
- [ ] **Krok 3:** W worktree dodaj `.macOS(.v27)` w: Core/Models, Core/Analytics, Core/CoreApp, Data/Services/SwiftDataManager, Data/Services/FirebaseService, Data/Services/MusicKitService, Data/Services/SpotifyService, Data/Repositories/MusicRepository, Data/Repositories/HomeRepository, Domain/HomeUseCases.
- [ ] **Krok 4:** Najtańszym sposobem doprowadź każdy z tych pakietów do zielonego `swift build --package-path <pkg>`: obuduj w `#if os(iOS)` deklaracje używające Firebase, MusicKit i UIKit, nadaj zależnościom SDK `condition: .when(platforms: [.iOS])` i usuń domyślne argumenty wskazujące obudowane typy.
- [ ] **Krok 5:** `swift test --package-path Data/Repositories/HomeRepository` oraz `swift test --package-path Domain/HomeUseCases`. Oczekiwane: PASS albo lista błędów.
- [ ] **Krok 6:** Każdy błąd z kroków 4–5, którego nie usuwa wprost żadne z zadań 1.1–1.8, wpisz do tabeli „Spike A” (pakiet, plik:linia, błąd, zadanie albo „nowe zadanie”). Każde „nowe zadanie” dopisz do fazy 1 przed rozpoczęciem PR 1.
- [ ] **Krok 7:** `git worktree remove ../BeatRate-spike-a && git branch -D spike/reflex-macos`.

### Task 0.2: Spike B — czy żądanie Apple niesie nonce (z użytkownikiem)

**Pliki:** tymczasowo `Presentation/Login/Sources/Login/LoginPromptView.swift`, bez commita.

- [ ] **Krok 1:** W `onCompletion` (gałąź `.success`) dodaj w `#if DEBUG` log jednej linii `NONCE-CHECK present=<Bool> matches=<Bool>`. Zdekoduj środkową część JWT z `ASAuthorizationAppleIDCredential.identityToken` (base64url), odczytaj claim `nonce` i porównaj go z `sha256` nonce'a z `getCurrentNonce()`.
- [ ] **Krok 2:** Uruchom build Debug na symulatorze. Użytkownik loguje się przez Sign in with Apple testowym Apple ID; odczytaj linię `NONCE-CHECK` z konsoli.
- [ ] **Krok 3:** Wpisz wynik do „Spike B” i cofnij zmianę (`git checkout -- Presentation/Login`). Jeśli wynik to `present=false` albo `matches=false`, zadanie 0.4 jest obowiązkowe; w przeciwnym razie je pomiń.

### Task 0.3: Pomiar bazowy

- [ ] **Krok 1:** Uruchom dwa razy z rzędu i zapisz czas drugiego przebiegu: `time xcodebuild test -scheme "BeatRate Development" -project BeatRate.xcodeproj -destination 'platform=iOS Simulator,name=iPhone Duo' -testPlan BeatRateDevelopmentTestPlan`.
- [ ] **Krok 2:** Dodaj linię komentarza w `Domain/HomeUseCases/Sources/HomeUseCases/HomeUseCases/GetHomeUseCase.swift`, zmierz to samo polecenie i cofnij zmianę.
- [ ] **Krok 3:** Zmierz drugi przebieg `time swift test --package-path Core/Models`.
- [ ] **Krok 4:** Wpisz trzy czasy i liczby testów do tabeli „Pomiar bazowy”, commit `Record Reflex phase 0 findings`, otwórz PR 0 do `development`.

### Task 0.4 (warunkowe): nonce gotowy przed żądaniem Apple

Wykonaj tylko wtedy, gdy Spike B wykazał brak albo niezgodność nonce'a (decyzja 24, opcja A). Wzorzec jest w `SettingsView.swift:181-189`.

**Pliki:**
- Modify: `Presentation/Login/Sources/Login/LoginDataModel.swift`
- Modify: `Presentation/Login/Sources/Login/LoginPromptView.swift:106-127`
- Test: `Presentation/Login/Tests/LoginTests/LoginDataModelTests.swift`, `LoginTestDoubles.swift`

**Interfejsy:** dostarcza `LoginDataModel.hashedNonce: String?` (`private(set)`) i `func prepareNonce() async`.

- [ ] **Krok 1: Test, który pada**

```swift
@Test func `the prepared nonce is the SHA-256 of the repository nonce`() async {
    useCases.nonce = "abc"   // dodaj `nonce` do stubu GetLoginUseCaseProtocol, jeśli go nie ma

    await model.prepareNonce()

    #expect(model.hashedNonce == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}
```

- [ ] **Krok 2:** `-only-testing:LoginTests` na symulatorze. Oczekiwane: FAIL (brak `prepareNonce`).
- [ ] **Krok 3:** `prepareNonce()` ustawia `hashedNonce = sha256(await getLoginUseCase.getCurrentNonce())`. Widok pokazuje `ProgressView`, dopóki `hashedNonce == nil`, i dostaje `.task { await dataModel.prepareNonce() }`. W `onRequest` ustaw synchronicznie `requestedScopes = [.fullName, .email]` i `nonce = dataModel.hashedNonce`, bez wewnętrznego `Task`.
- [ ] **Krok 4:** `-only-testing:LoginTests` → PASS; `BuildProject` → OK; powtórz Spike B (oczekiwane `present=true matches=true`), potem usuń log.
- [ ] **Krok 5:** Commit `Prepare the Sign in with Apple nonce before the request`, otwórz PR 0b.

---

## Faza 1

### Task 1.1: Models budują się na macOS i kodują stan do JSON

**Pliki:**
- Modify: `Core/Models/Package.swift` → `platforms: [.iOS(.v27), .macOS(.v27)]`
- Modify (`import SwiftUI` → `import Foundation`): `AlbumModel.swift`, `HomeSection.swift`, `AppleMusicArtist.swift`, `FirebaseAlbumSection.swift`, `AppleMusicAlbum.swift`; w `User.swift` usuń `import SwiftUI` (`SwiftData` zostaje)
- Modify: `AlbumModel`, `HomeSection` i `MusicSearchResults` dostają `Encodable` (synteza kompilatora)
- Test: `Core/Models/Tests/ModelsTests/EncodableStateTests.swift` (nowy)

**Interfejsy:** dostarcza `AlbumModel: Encodable`, `HomeSection: Encodable`, `MusicSearchResults: Encodable` (stan ekranów w fazie 2).

- [ ] **Krok 1: Testy, które padają.** `Self.object(_:)` to `try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] ?? [:]`.

```swift
@Test func `an album model encodes everything its screen shows`() throws {
    let album = AlbumModel(id: "1", appleMusicAlbumData: .albumPlaceholder,
                           firebaseAlbumData: FirebaseAlbumData(artist: "A", avgRating: 8.5, createdAt: 1, ratingCount: 2, title: "T"),
                           userRating: 7)
    let json = try Self.object(album)
    #expect(Set(json.keys) == ["id", "appleMusicAlbumData", "firebaseAlbumData", "userRating"])
    #expect(json["userRating"] as? Double == 7)
}

@Test func `a home section encodes its names and albums`() throws {
    let json = try Self.object(HomeSection(name: "New", analyticsName: "new", albums: [.albumPlaceholder]))
    #expect(json["name"] as? String == "New")
    #expect(json["analyticsName"] as? String == "new")
    #expect((json["albums"] as? [Any])?.count == 1)
}

@Test func `search results encode albums and artists`() throws {
    let json = try Self.object(MusicSearchResults(albums: [.albumPlaceholder], artists: []))
    #expect(Set(json.keys) == ["albums", "artists"])
}
```

- [ ] **Krok 2:** `swift test --package-path Core/Models`. Oczekiwane: FAIL (typy nie są `Encodable`).
- [ ] **Krok 3:** Dodaj `Encodable` do trzech typów i zamień importy.
- [ ] **Krok 4:** `swift test --package-path Core/Models` → PASS; `grep -rn 'import SwiftUI' Core/Models/Sources` → pusto; `BuildProject` → OK.
- [ ] **Krok 5:** Commit `Build Models on macOS and make screen state encodable`.

### Task 1.2: Jeden `Graph` zamiast singletonów

To refaktor bez nowego zachowania, więc siatką są istniejące testy. `Graph` dostanie własne testy w zadaniu 1.7, gdy da się go zbudować bez dysku i bez Firebase.

**Pliki:**
- Create: `Domain/Composition/Package.swift` — pakiet `Composition`, na razie `platforms: [.iOS(.v27)]` (macOS w 1.8), produkt i target `Composition` z `.defaultIsolation(MainActor.self)`. Target zależy od wszystkich 8 pakietów Domain, 5 Repositories, 4 Services oraz od Core/Analytics, Core/CoreApp i Core/Models.
- Create: `Domain/Composition/Sources/Composition/Graph.swift`
- Modify — usuń `static let shared` w: `AnalyticsManager.swift:14`, `UserDefaultsManager.swift:10`, `MusicPlayerManager.swift:14`, `KeychainManager.swift:19`, `SessionManager.swift:33`, `SearchRepository.swift:19`, `LoginRepository.swift:29`, `HomeRepository.swift:32`, `MusicRepository.swift:72`, `AccountRepository.swift:27`, `SpotifyService.swift:16`, `DatabaseFirebaseService.swift:31`, `AuthFirebaseService.swift:31`, `MusicKitService.swift:14`, `SwiftDataManager.swift:58`. `CrashLogger.shared` zostaje.
- Modify — usuń w Core, Data i Domain każdy domyślny argument, który wskazuje singleton albo tworzy use case. Listę daje `grep -rnE '= ([A-Z][A-Za-z]+\.)?shared\b|= [A-Z][A-Za-z]+UseCase\(\)' Core Data Domain --include='*.swift' | grep -v /Tests/`; po zmianie zostają w niej tylko linie `crashLogger: CrashLogger = .shared`.
- Modify — nadaj `public`, bo `Graph` leży w innym module: `LoginRepository.init(authFirebaseService:databaseFirebaseService:)`, `AuthFirebaseService.init(analyticsManager:crashLogger:databaseService:keychainManager:)`, `SwiftDataManager.init(container:appleUserIDStore:now:)` i `static func makeContainer(...)`, protokół `AppleUserIDStore`, `KeychainManager.init(backend:)` razem z protokołem `KeychainBackend` i `SecItemKeychainBackend` (z `public init()`), `AnalyticsManager.init(defaults:)` (convenience z backendem Firebase). `DatabaseFirebaseService`: dzisiejszy `private init(analyticsManager:crashLogger:)` staje się `public init(analyticsManager: AnalyticsManager, crashLogger: CrashLogger)`.
- Modify Presentation: domyślne argumenty według tabeli niżej, a w każdym `Package.swift` zależność `.package(path: "../../Domain/Composition")` i `"Composition"`. Pliki: Account (`AccountDataModel.swift`, `AccountGuestDataModel.swift`, `FavoritesManagerModel.swift`), AlbumDetails (`AlbumDetailsContainer.swift`, `AlbumDetailsDataModel.swift`), `ArtistDetailsDataModel.swift`, `HomeDataModel.swift`, `LoginDataModel.swift`, `MusicPlayerPickerDataModel.swift`, `SearchDataModel.swift`, `SettingsDataModel.swift`, `SplashDataModel.swift`, `TabBarView.swift:62`.
- Modify App: `AppDelegate.swift`, `AppDataModel.swift:52-56`, `BeatRateApp.swift`, `BeatRate.xcodeproj/project.pbxproj` (produkt `Composition` w obu targetach aplikacji).

**Interfejsy (dostarcza):**

```swift
/// Builds the app's objects once: one instance of every service, repository and use case per process.
public final class Graph {
    /// ponytail: transitional. Read only by legacy DataModels, TabBarView and AppDelegate; phase 6 removes it.
    public static var current: Graph!

    public let analytics: AnalyticsManager
    public let session: SessionManager
    public let players: MusicPlayerManager
    public let getApp: any GetAppUseCaseProtocol
    public let getHome: any GetHomeUseCaseProtocol
    public let setHome: any SetHomeUseCaseProtocol
    public let getAlbumById: any GetAlbumByIdUseCaseProtocol
    public let getAlbumDetails: any GetAlbumDetailsUseCaseProtocol
    public let getArtistDetails: any GetArtistDetailsUseCaseProtocol
    public let getSearch: any GetSearchUseCaseProtocol
    public let getRecentAlbums: any GetRecentAlbumsUseCaseProtocol
    public let saveRecentAlbum: any SaveRecentAlbumUseCaseProtocol
    public let clearRecentAlbums: any ClearRecentAlbumsUseCaseProtocol
    public let getLogin: any GetLoginUseCaseProtocol
    public let setLogin: any SetLoginUseCaseProtocol
    public let getAccount: any GetAccountUseCaseProtocol
    public let setAccount: any SetAccountUseCaseProtocol
    public let getSettings: any GetSettingsUseCaseProtocol
    public let setSettings: any SetSettingsUseCaseProtocol
    public let getSplash: any GetSplashUseCaseProtocol

    public init()   // zadanie 1.7 zastępuje je `init(edges:)`
}
```

Reguła ciała `init()`: dokładnie jedna instancja każdego z obiektów `UserDefaultsManager(defaults: .standard)`, `KeychainManager()`, `AnalyticsManager(defaults: .standard)`, `SessionManager()`, `MusicPlayerManager`, `SwiftDataManager(container: SwiftDataManager.makeContainer(), appleUserIDStore: keychain)`, `DatabaseFirebaseService`, `AuthFirebaseService`, `MusicKitService`, `SpotifyService` oraz każdego repozytorium. Każdy use case powstaje raz, z tych instancji; `GetSettingsUseCase`, `SetSettingsUseCase` i `GetSplashUseCase` dostają `getLogin` i `setLogin` z grafu. Jako `crashLogger` wszędzie trafia `CrashLogger.shared`.

| Domyślny argument dziś | Po zmianie |
| --- | --- |
| `analyticsManager: AnalyticsManager = .shared` | `= Graph.current.analytics` |
| `sessionManager: SessionManager = .shared` | `= Graph.current.session` |
| `musicPlayerManager: MusicPlayerManager = .shared` | `= Graph.current.players` |
| `getHomeUseCase: … = GetHomeUseCase()` i każde inne `…UseCase()` | właściwość `Graph.current` o nazwie z interfejsu (`getHome`, `getSplash`, …) |
| `crashLogger: CrashLogger = .shared` | bez zmian |

- [ ] **Krok 1:** Utwórz pakiet i `Graph` według interfejsu i reguły.
- [ ] **Krok 2:** Usuń singletony i domyślne argumenty w Core, Data i Domain; nadaj `public` elementom z listy.
- [ ] **Krok 3:** Zmień domyślne argumenty w Presentation i App według tabeli; `TabBarView.swift:62` loguje przez `Graph.current.analytics`.
- [ ] **Krok 4:** W `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, po `FirebaseApp.configure()` i konfiguracji bazy, ustaw `Graph.current = Graph()`. W `Task` użyj `Graph.current.analytics` zamiast `AnalyticsManager.shared`. W `BeatRateApp` usuń `cacheManager`, `.modelContainer(…)`, `.environmentObject(…)` oraz importy `SwiftData` i `SwiftDataManager`.
- [ ] **Krok 5:** Podłącz produkt `Composition` do targetów `BeatRate` i `BeatRate Development`. W Xcode: target → General → Frameworks, Libraries → + → Composition. Alternatywnie edytuj `project.pbxproj` na wzór wpisów `Login`: `XCSwiftPackageProductDependency` z `productName = Composition;`, `PBXBuildFile` „Composition in Frameworks”, linia w fazach `Frameworks` (`8BED07EB2DE0D68300838DD7`, `8BED08412DE0DBFB00838DD7`) i w `packageProductDependencies` obu targetów. Nowy pakiet w `Domain/` Xcode wykryje sam, tak jak `SearchUse`.
- [ ] **Krok 6:** `BuildProject` dla obu schematów → OK.
- [ ] **Krok 7:** Pełny plan testów Development na iPhone Duo → wszystko PASS. Błąd kompilacji testu po usunięciu domyślnego argumentu albo crash „Unexpectedly found nil” (test polegał na singletonie) naprawiasz, podając istniejący dubler przez `init`.
- [ ] **Krok 8:** `grep -rn 'static let shared' Core Data Domain` → tylko `CrashLogger.swift`.
- [ ] **Krok 9:** Smoke na symulatorze: start po usunięciu aplikacji, załadowany Home, logowanie, ocena albumu, wylogowanie. Logowanie Apple wykonuje użytkownik.
- [ ] **Krok 10:** Commit `Build the object graph once in Composition instead of singletons`, otwórz PR 1 (zadania 1.1–1.2).

### Task 1.3: Analytics bez Firebase; CoreApp i SwiftDataManager na macOS

**Pliki:**
- Modify: `Core/Analytics/Package.swift` — `platforms: [.iOS(.v27), .macOS(.v27)]`. Produkty: `Analytics`, `AnalyticsFirebase`. Targety: `Analytics` (bez zależności); `AnalyticsFirebase` (`"Analytics"`, `.product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS]))` i to samo dla `FirebaseAnalytics`); `AnalyticsTests` (`"Analytics"`).
- Create: `Core/Analytics/Sources/AnalyticsFirebase/FirebaseBackends.swift` w `#if os(iOS)`, z `public struct FirebaseAnalyticsBackend: AnalyticsBackend` i `nonisolated public struct FirebaseCrashBackend: CrashBackend`. Każdy ma `public init() {}`, a ciała przechodzą bez zmian. Klasę Firebase wołaj jako `FirebaseAnalytics.Analytics`, bo nasz moduł też nazywa się `Analytics`.
- Modify: `AnalyticsEvent.swift` — bez `import FirebaseAnalytics`. Stałe zamieniamy na literały: `AnalyticsEventScreenView` → `"screen_view"`, `AnalyticsEventSearch` → `"search"`, `AnalyticsEventSignUp` → `"sign_up"`, `AnalyticsEventLogin` → `"login"`, `AnalyticsParameterScreenName` → `"screen_name"`, `AnalyticsParameterScreenClass` → `"screen_class"`, `AnalyticsParameterMethod` → `"method"`.
- Modify: `AnalyticsManager.swift` — `import Foundation` zamiast `FirebaseAnalytics` i `SwiftUI`; bez `convenience init(defaults:)` i bez `FirebaseAnalyticsBackend`.
- Modify: `CrashLogger.swift` — bez `import FirebaseCrashlytics` i bez `FirebaseCrashBackend`. Backend trzymamy w `Mutex<any CrashBackend>`, a `shared = CrashLogger(backend: NoCrashBackend())`. Dochodzi `nonisolated public func use(_ backend: any CrashBackend)`. Metody czytają backend przez `withLock { $0 }` i wołają go poza blokadą. `nonisolated struct NoCrashBackend: CrashBackend` ma puste metody, bo OSLog pisze sam `CrashLogger`.
- Modify: `Graph.swift` — pierwsza linia `init()` to `CrashLogger.shared.use(FirebaseCrashBackend())`, a `analytics = AnalyticsManager(defaults: .standard, backend: FirebaseAnalyticsBackend())`. `Domain/Composition/Package.swift` dostaje zależność od produktu `AnalyticsFirebase`.
- Modify: `Core/CoreApp/Package.swift` i `Data/Services/SwiftDataManager/Package.swift` — dochodzi `.macOS(.v27)`. W `SwiftDataManager.swift` `import SwiftUI` → `import Foundation` i bez `ObservableObject`.
- Test: `Core/Analytics/Tests/AnalyticsTests/CrashLoggerTests.swift`, `AnalyticsEventTests.swift`, `AnalyticsTestDoubles.swift`.

**Interfejsy:** dostarcza `CrashLogger.use(_:)` oraz produkt `AnalyticsFirebase` z `FirebaseAnalyticsBackend()` i `FirebaseCrashBackend()`.

- [ ] **Krok 1: Testy, które padają.** `StubCrashBackend` dopisz do `AnalyticsTestDoubles.swift`, jeśli go nie ma: `final class` z `Mutex<[String]>`, a `log` zapisuje wiadomość (wzór: `StubCrashBackend` w `BeatRateDevelopmentTests.swift`).

```swift
@Test func `a backend installed later receives the logs`() {
    let first = StubCrashBackend(), second = StubCrashBackend()
    let logger = CrashLogger(backend: first)

    logger.use(second)
    logger.log("boom", to: nil, level: .error, file: "Module/File.swift")

    #expect(first.messages.isEmpty)
    #expect(second.messages == ["[Module] boom"])
}
```

W parametryzowanej tabeli `AnalyticsEventTests` dopisz `.signUp` z nazwą `"sign_up"` i parametrami `["method": "apple"]`. Dla `.screenView(.home)` dopisz parametry `"screen_name": "home"` i `"screen_class": "home"`, jeśli tabela ich jeszcze nie sprawdza.

- [ ] **Krok 2:** `swift test --package-path Core/Analytics`. Oczekiwane: FAIL (brak `use`).
- [ ] **Krok 3:** Wprowadź zmiany z listy plików.
- [ ] **Krok 4:** Na macOS `swift test` dla `Core/Analytics`, `Core/CoreApp` i `Data/Services/SwiftDataManager` → PASS. Pokrycie `Core/Analytics` 100% poza `NoCrashBackend`. `BuildProject` → OK. Na symulatorze `-only-testing:AnalyticsTests -only-testing:SwiftDataManagerTests` → PASS.
- [ ] **Krok 5:** Commit `Move Firebase analytics backends out of the Analytics logic`.

### Task 1.4: FirebaseService — logika bez SDK, adaptery w FirebaseServiceLive

**Pliki:**
- Modify: `Data/Services/FirebaseService/Package.swift` — dochodzi macOS. Produkty: `FirebaseService`, `FirebaseServiceLive`. Targety: `FirebaseService` (Analytics, Models, CoreApp); `FirebaseServiceLive` (`"FirebaseService"` oraz `FirebaseAuth` i `FirebaseDatabase` z `.when(platforms: [.iOS])`); `FirebaseServiceTests`.
- Modify: `RealtimeDatabase.swift` — `DatabaseValue` (z `public let raw` i `public init(_:)`) oraz `RealtimeDatabase` stają się publiczne. `FirebaseRealtimeDatabase` i `import FirebaseDatabase` wychodzą z pliku.
- Create: `Sources/FirebaseService/FirebaseAuthProviding.swift`
- Modify: `AuthFirebaseService.swift` — bez `FirebaseAuth` i `SwiftUI`. Każde wywołanie `Auth.auth()` i `OAuthProvider` idzie przez `auth`, a init to `public init(auth:analyticsManager:crashLogger:databaseService:keychainManager:)`. `revokeAndDeleteUser` najpierw robi `guard await auth.currentUserId() != nil else { throw AuthFirebaseServiceError.noCurrentUser }`. Potem odwołuje token (błąd jest niekrytyczny, jak dziś), a na końcu woła `try await auth.deleteCurrentUser()`.
- Modify: `DatabaseFirebaseService.swift` — znika init z zadania 1.2. Zostaje publiczny `init(analyticsManager:crashLogger:database:now:)`, a `import SwiftUI` zamienia się na `import Foundation`.
- Create (w `#if os(iOS)`): `Sources/FirebaseServiceLive/FirebaseRealtimeDatabase.swift` (przeniesiony, `public struct`, `public init(url:)`) i `Sources/FirebaseServiceLive/FirebaseAuthProvider.swift` (`public struct FirebaseAuthProvider: FirebaseAuthProviding`, `public init()`, ciała przeniesione z `AuthFirebaseService`).
- Modify: `Graph.swift` — `DatabaseFirebaseService(analyticsManager:crashLogger:database: FirebaseRealtimeDatabase(url: AppEnvironment.current.firebaseDatabaseUrl))` i `AuthFirebaseService(auth: FirebaseAuthProvider(), …)`. Composition dostaje zależność od produktu `FirebaseServiceLive`.
- Test: `Tests/FirebaseServiceTests/AuthSessionTests.swift` (nowy), `AuthProfileTests.swift`, `FirebaseServiceTestDoubles.swift`.

**Interfejsy (dostarcza):**

```swift
public struct FirebaseSignIn: Sendable {
    public let userId: String
    public let email: String?
    public let isNewUser: Bool
    public init(userId: String, email: String?, isNewUser: Bool)
}

/// The Firebase Auth calls the app makes, so the sign-in logic runs without the SDK.
public protocol FirebaseAuthProviding: Sendable {
    func currentUserId() async -> String?
    func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> FirebaseSignIn
    func signOut() async throws
    /// Throws `AuthFirebaseServiceError.noCurrentUser` when nobody is signed in.
    func reauthenticate(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws
    func revokeToken(authorizationCode: String) async throws
    /// Throws `AuthFirebaseServiceError.noCurrentUser` when nobody is signed in.
    func deleteCurrentUser() async throws
}
```

- [ ] **Krok 1: Testy, które padają.** Dublery w `FirebaseServiceTestDoubles.swift`:
  - `StubFirebaseAuth` to `actor` ze skryptowanymi `signInResult`, `currentUser` i `revokeError`, który liczy `signOutCount` i `deleteCount`.
  - `StubKeychainBackend(failing:)` zwraca `errSecIO` z `add` i `update`.
  - `StubAnalyticsBackend` zapisuje `events: [(name: String, parameters: [String: Any]?)]`, jak w testach Analytics.
  - `Self.credential` to `AppleSignInCredential(user: "apple-1", identityToken: Data("token".utf8), authorizationCode: nil, email: nil, fullName: nil)`.

```swift
@Test func `a keychain failure signs the new Firebase session back out`() async {
    let auth = StubFirebaseAuth(signInResult: .init(userId: "u1", email: nil, isNewUser: true))
    let service = Self.service(auth: auth, keychain: StubKeychainBackend(failing: true))

    await #expect(throws: (any Error).self) {
        _ = try await service.setLoginData(idTokenString: "token", nonce: "nonce", credential: Self.credential)
    }
    #expect(await auth.signOutCount == 1)
}

@Test(arguments: [(true, "sign_up"), (false, "login")])
func `only the first sign-in is reported as a sign up`(isNewUser: Bool, event: String) async throws {
    let auth = StubFirebaseAuth(signInResult: .init(userId: "u1", email: nil, isNewUser: isNewUser))
    let (service, analytics) = Self.serviceWithAnalytics(auth: auth)

    _ = try await service.setLoginData(idTokenString: "token", nonce: "nonce", credential: Self.credential)

    #expect(analytics.events.map(\.name).contains(event))
}

@Test func `deleting with nobody signed in throws noCurrentUser`() async {
    let service = Self.service(auth: StubFirebaseAuth(currentUser: nil))

    await #expect(throws: AuthFirebaseServiceError.noCurrentUser) {
        try await service.revokeAndDeleteUser(authorizationCode: "code")
    }
}

@Test func `a failed token revoke still deletes the account`() async throws {
    let auth = StubFirebaseAuth(currentUser: "u1", revokeError: StubError())

    try await Self.service(auth: auth).revokeAndDeleteUser(authorizationCode: "code")

    #expect(await auth.deleteCount == 1)
}
```

- [ ] **Krok 2:** `swift test --package-path Data/Services/FirebaseService`. Oczekiwane: FAIL (brak `FirebaseAuthProviding`).
- [ ] **Krok 3:** Wprowadź zmiany z listy plików; `AuthProfileTests` budują serwis ze `StubFirebaseAuth`.
- [ ] **Krok 4:** `swift test --package-path Data/Services/FirebaseService` → PASS. Pokrycie targetu `FirebaseService` 100%; `FirebaseServiceLive` jest wyjątkiem jako cienki adapter SDK (wpisz w opis PR-a). `BuildProject` → OK.
- [ ] **Krok 5:** Commit `Put Firebase Auth and Realtime Database behind seams in FirebaseServiceLive`.

### Task 1.5: MusicKitService — protokół bez MusicKit, implementacja w MusicKitServiceLive

**Pliki:**
- Modify: `Data/Services/MusicKitService/Package.swift` — dochodzi macOS. Produkty: `MusicKitService`, `MusicKitServiceLive`. Targety: `MusicKitService` (Analytics, Models), `MusicKitServiceLive` (`"MusicKitService"`, `"Models"`, `"Analytics"`). Testy: `MusicKitServiceTests` (`"MusicKitService"`) i `MusicKitServiceLiveTests` (`"MusicKitServiceLive"`).
- Modify: `MusicKitServiceProtocol.swift` — bez `import MusicKit`. `MusicAuthorizationResult.status` ma typ `MusicAccessStatus`, nowy `public enum MusicAccessStatus: Sendable { case notDetermined, denied, restricted, authorized }`.
- Modify: `Networking/AppleMusicDataSource.swift` — zostaje sam publiczny protokół, bez `import MusicKit`. `MusicKitDataSource` przechodzi do Live.
- Move do `Sources/MusicKitServiceLive/` (wszystko w `#if os(iOS)`):
  - `MusicKitService.swift` bez nieużywanego `analyticsManager`, z `public init()` i `init(dataSource:)`;
  - `MusicKitDataSource.swift`;
  - nowy `MusicAccessStatus+MusicKit.swift` z `init(_ status: MusicAuthorization.Status)`.
- Modify: `MusicRepository.swift:98-113` — `switch` po `MusicAccessStatus`, bez gałęzi `default`.
- Move testy do `Tests/MusicKitServiceLiveTests/` (w `#if os(iOS)`, z `@testable import MusicKitServiceLive`, konstruktory bez `analyticsManager:`): `CatalogMappingTests.swift`, `FetchTracksTests.swift`, `MusicKitHelpersTests.swift`, `MusicKitServiceTestDoubles.swift`. `AppleMusicAPITests.swift` zostaje na miejscu.
- Modify: oba pliki `.xctestplan` — target `MusicKitServiceLiveTests` z `containerPath` `container:Data/Services/MusicKitService`.
- Modify: `Graph.swift` — `MusicKitService()` z modułu `MusicKitServiceLive`; Composition dostaje zależność od tego produktu.
- Test: `Tests/MusicKitServiceLiveTests/MusicAccessStatusTests.swift` (nowy).

**Interfejsy:** dostarcza `MusicAccessStatus` i `MusicAuthorizationResult(status: MusicAccessStatus, hasSubscription: Bool)`.

- [ ] **Krok 1: Test, który pada**

```swift
@Test(arguments: [
    (MusicAuthorization.Status.notDetermined, MusicAccessStatus.notDetermined),
    (.denied, .denied), (.restricted, .restricted), (.authorized, .authorized),
])
func `every MusicKit authorization status keeps its meaning`(status: MusicAuthorization.Status, expected: MusicAccessStatus) {
    #expect(MusicAccessStatus(status) == expected)
}
```

- [ ] **Krok 2:** `-only-testing:MusicKitServiceLiveTests` na symulatorze. Oczekiwane: FAIL.
- [ ] **Krok 3:** Wprowadź zmiany z listy plików. Jeśli kompilator zgłosi niejednoznaczność nazwy `MusicKitService` (moduł kontra aktor), zmień nazwę aktora na `LiveMusicKitService`.
- [ ] **Krok 4:** `swift test --package-path Data/Services/MusicKitService` na macOS → PASS (`AppleMusicAPITests`). Na symulatorze `-only-testing:MusicKitServiceLiveTests -only-testing:MusicRepositoryTests` → PASS. `BuildProject` → OK.
- [ ] **Krok 5:** Commit `Move the MusicKit implementation to MusicKitServiceLive`.

### Task 1.6: SpotifyService — arkusz OAuth w SpotifyServiceLive

To przeniesienie kodu: nowego zachowania nie ma, a siatką są istniejące testy parsowania i autoryzacji.

**Pliki:**
- Modify: `Data/Services/SpotifyService/Package.swift` — dochodzi macOS. Produkty: `SpotifyService`, `SpotifyServiceLive`. Nowy target `SpotifyServiceLive` zależy od `"SpotifyService"` i `"Analytics"`.
- Create: `Sources/SpotifyService/Auth/SpotifyAuthorizationPresenter.swift` — przeniesiony protokół, teraz `public`.
- Create: `Sources/SpotifyService/Auth/SpotifyAuthorizationCallback.swift` — `public enum SpotifyAuthorizationCallback` z przeniesionym bez zmian `static func authorizationCode(from:error:)` (dziś `SpotifyWebAuthSession.swift:74`), teraz `public`. Wewnętrzne typy z jego sygnatury też stają się `public`; `SpotifyFailure` już jest publiczne.
- Move: `SpotifyWebAuthSession.swift` → `Sources/SpotifyServiceLive/`, w `#if os(iOS)`. Klasa jest `public final`, z `public static func make()` i publicznym `authorize(url:callbackScheme:)`, a callback parsuje przez `SpotifyAuthorizationCallback`.
- Modify: `SpotifySession.init` — `makePresenter` bez wartości domyślnej.
- Modify: `SpotifyService` — `public init(clientId: String = AppEnvironment.current.spotifyClientId, redirectUri: String = AppEnvironment.current.spotifyRedirectUri, keychainManager: KeychainManager, makePresenter: @escaping @Sendable () async -> (any SpotifyAuthorizationPresenter)?)`.
- Modify: `Graph.swift` — `SpotifyService(keychainManager: keychain, makePresenter: { @MainActor in SpotifyWebAuthSession.make() })`. Composition dostaje zależność od produktu `SpotifyServiceLive`.
- Modify: `Tests/SpotifyServiceTests/SpotifyConnectionTests.swift:49,57,63` — wołają `SpotifyAuthorizationCallback.authorizationCode(…)`. Testy budujące `SpotifySession` bez prezentera podają `{ nil }`.

**Interfejsy:** dostarcza publiczne `SpotifyAuthorizationPresenter`, `SpotifyAuthorizationCallback.authorizationCode(from:error:)` i `SpotifyService.init(…makePresenter:)`.

- [ ] **Krok 1:** Przenieś kod według listy plików.
- [ ] **Krok 2:** `swift test --package-path Data/Services/SpotifyService` na macOS → PASS; pokrycie targetu `SpotifyService` nie spada; `BuildProject` → OK.
- [ ] **Krok 3:** Commit `Move the Spotify sign-in sheet to SpotifyServiceLive`.

### Task 1.7: Edges — host wybiera krawędzie, Graph je składa

**Pliki:**
- Create: `Domain/Composition/Sources/Composition/Edges.swift`
- Modify: `Graph.swift` — `public init(edges: Edges)` zastępuje `init()`. Pierwsza linia to `CrashLogger.shared.use(edges.crash)`, a każda krawędź pochodzi z `edges`.
- Create: `Domain/Composition/Sources/CompositionLive/Edges+Live.swift` w `#if os(iOS)`.
- Modify: `Domain/Composition/Package.swift`:
  - target `Composition` zależy już tylko od pakietów logiki;
  - target `CompositionLive` zależy od `"Composition"`, od pakietów logiki, których symboli używa `Edges.live()` (`CoreApp`, `SwiftDataManager`, `SplashUseCases`, `SpotifyService`, `FirebaseService`), oraz od produktów `FirebaseServiceLive`, `MusicKitServiceLive`, `SpotifyServiceLive` i `AnalyticsFirebase`, każdy z `.when(platforms: [.iOS])`;
  - dochodzi target `CompositionTests` (`"Composition"`);
  - produkt `Composition` obejmuje `["Composition", "CompositionLive"]`, więc aplikacja dalej linkuje jeden produkt.
- Modify (stają się `public`): `SpotifyTransport`, `URLSessionTransport` (z `public init()`), `GetSplashUseCase.init(…credentialStore:credentialState:)`, `AppleCredentialStore` i `GetSplashUseCase.fetchAppleIDCredentialState` (`public nonisolated static`). `SpotifyService.init` dostaje parametr `transport: any SpotifyTransport`.
- Modify: `AppDelegate.swift` — importuje `Composition` i `CompositionLive`, a zamiast `Graph()` ustawia `Graph.current = Graph(edges: .live())`.
- Modify: oba pliki `.xctestplan` — target `CompositionTests` (`container:Domain/Composition`).
- Test: `Domain/Composition/Tests/CompositionTests/GraphTests.swift` i `CompositionTestDoubles.swift`. Ten drugi plik ma `static func stub(defaults: UserDefaults = UserDefaults(suiteName: "Graph.\(UUID())")!, analytics: any AnalyticsBackend = StubAnalyticsBackend()) -> Edges` ze stubami wszystkich krawędzi i `modelContainer: SwiftDataManager.inMemory().container`.

**Interfejsy (dostarcza):**

```swift
public struct Edges {
    public var database: any RealtimeDatabase
    public var firebaseAuth: any FirebaseAuthProviding
    public var musicKit: any MusicKitServiceProtocol
    public var spotifyTransport: any SpotifyTransport
    public var spotifyPresenter: @Sendable () async -> (any SpotifyAuthorizationPresenter)?
    public var keychain: any KeychainBackend
    public var appleIDCredentialState: @Sendable (String) async -> ASAuthorizationAppleIDProvider.CredentialState
    public var defaults: UserDefaults
    public var modelContainer: ModelContainer
    public var analytics: any AnalyticsBackend
    public var crash: any CrashBackend
    public init(/* wszystkie pola, w tej kolejności */)
}
```

Wartości w `Edges.live()`, po kolei: `FirebaseRealtimeDatabase(url: AppEnvironment.current.firebaseDatabaseUrl)`, `FirebaseAuthProvider()`, `MusicKitService()`, `URLSessionTransport()`, `{ @MainActor in SpotifyWebAuthSession.make() }`, `SecItemKeychainBackend()`, `GetSplashUseCase.fetchAppleIDCredentialState`, `.standard`, `SwiftDataManager.makeContainer()`, `FirebaseAnalyticsBackend()`, `FirebaseCrashBackend()`.

- [ ] **Krok 1: Testy, które padają**

```swift
@Test func `a graph built from stub edges starts as a guest`() async {
    let graph = Graph(edges: .stub())

    #expect(await graph.getApp.isUserLoggedIn() == false)
}

@Test func `analytics consent stored in the given defaults is respected`() {
    let defaults = UserDefaults(suiteName: "Graph.\(UUID())")!
    defaults.set(true, forKey: "analyticsConsent")

    #expect(Graph(edges: .stub(defaults: defaults)).analytics.consent == true)
}

@Test func `analytics events reach the backend from the edges`() {
    let backend = StubAnalyticsBackend()
    let graph = Graph(edges: .stub(analytics: backend))

    graph.analytics.setAnalyticsEnabled(true)
    graph.analytics.log(.screenView(.home))

    #expect(backend.events.map(\.name) == ["screen_view"])
}
```

- [ ] **Krok 2:** `-only-testing:CompositionTests` na symulatorze. Oczekiwane: FAIL (brak `Edges`).
- [ ] **Krok 3:** Wprowadź zmiany z listy plików.
- [ ] **Krok 4:** `-only-testing:CompositionTests` → PASS; `BuildProject` dla obu schematów → OK; pełny plan testów Development → PASS.
- [ ] **Krok 5:** Commit `Let the host choose the edges the graph is built from`, otwórz PR 2 (zadania 1.3–1.7).

### Task 1.8: Cała logika na macOS, `./test`, strażnik i dokumentacja

**Pliki:**
- Modify (`.macOS(.v27)`): `Data/Repositories/{AccountRepository,HomeRepository,LoginRepository,MusicRepository,SearchRepository}/Package.swift` oraz `Domain/{AccountUseCases,AppUseCases,ArtistUseCase,HomeUseCases,LoginUseCases,SearchUse,SettingUseCases,SplashUseCases,Composition}/Package.swift`.
- Modify (`import SwiftUI` → `import Foundation`): `LoginRepository.swift`, `SetLoginUseCase.swift`, `GetLoginUseCase.swift` (tu także nieużywany `import AuthenticationServices`), `GetSplashUseCase.swift`, `GetAccountUseCase.swift`, `SetHomeUseCase.swift`, `GetHomeUseCase.swift`.
- Delete: `Core/CoreUI/Sources/CoreUI/ViewModifiers/ViewFirstAppearModifier.swift` (nieużywany).
- Create: `test` (wykonywalny skrypt w katalogu głównym repo).
- Modify: `CLAUDE.md`.

Treść `./test`. Lista pakietów i wzorzec strażnika to decyzje, więc podaję je w całości:

```bash
#!/bin/bash
# Logic packages on macOS, then the architecture guard. `./test Core/Models` runs one package.
set -euo pipefail
cd "$(dirname "$0")"
PACKAGES=(Core/Models Core/Analytics Core/CoreApp Data/Services/SwiftDataManager Data/Services/FirebaseService
  Data/Services/MusicKitService Data/Services/SpotifyService Data/Repositories/MusicRepository
  Data/Repositories/SearchRepository Data/Repositories/HomeRepository Data/Repositories/LoginRepository
  Data/Repositories/AccountRepository Domain/AppUseCases Domain/ArtistUseCase Domain/HomeUseCases
  Domain/LoginUseCases Domain/SearchUse Domain/AccountUseCases Domain/SettingUseCases Domain/SplashUseCases
  Domain/Composition)
if [ $# -gt 0 ]; then PACKAGES=("$@"); fi
for package in "${PACKAGES[@]}"; do swift test --package-path "$package"; done

# SDK and UI imports belong in …Live targets and App/ only: the logic must keep building headless.
leaks=$(grep -rnE '^(@preconcurrency |@_exported )?import ((struct|class|enum|protocol|func) )?(SwiftUI|UIKit|MusicKit|Firebase(Core|Auth|Database|Analytics|Crashlytics))(\.| *$)' \
  Core/Models/Sources Core/CoreApp/Sources Core/Analytics/Sources/Analytics Data/*/*/Sources Domain/*/Sources \
  | grep -vE '/Sources/[A-Za-z]*Live/' || true)
[ -z "$leaks" ] || { echo "SDK or UI import in logic:"; echo "$leaks"; exit 1; }
```

Zmiany w `CLAUDE.md`:

- **Build & Run:** blok „`swift test` does not work in this repo” zastąp akapitem: logika (Core/Models, Core/CoreApp, Core/Analytics, Data/*, Domain/*) buduje się i testuje na macOS. `./test` uruchamia wszystkie te pakiety ze strażnikiem, a `./test Domain/HomeUseCases` jeden pakiet. Presentation/*, Core/CoreUI i targety `…Live` testujemy planem testów w Xcode.
- **Dependency Injection:** każdy serwis, repozytorium i use case buduje raz `Graph(edges:)` w `Domain/Composition`, a `AppDelegate` ustawia `Graph.current = Graph(edges: .live())`. Singletonem zostaje tylko `CrashLogger.shared`. Stare DataModele biorą domyślne zależności z `Graph.current`, a nowy kod dostaje je przez `init`.
- **Nowa reguła:** kod SDK (Firebase, MusicKit, UIKit) żyje tylko w targetach `…Live` i w `App/`. Każdy plik `…Live` jest w `#if os(iOS)`, a jego zależności SDK mają `.when(platforms: [.iOS])`, bo `swift test` buduje wszystkie targety pakietu.
- **SwiftData Setup:** `SwiftDataManager` buduje `Graph` z `Edges.modelContainer`, a w `Edges.live()` jest to `SwiftDataManager.makeContainer()`. Widoki go nie czytają.
- **Running a module's tests and checking coverage:** dopisz `./test <pkg>` oraz komendę pokrycia na macOS z sekcji „Gałęzie i PR-y”.

- [ ] **Krok 1:** Dodaj platformy i zamień importy według listy plików.
- [ ] **Krok 2:** Utwórz `test` (`chmod +x test`), usuń `ViewFirstAppearModifier.swift`, zaktualizuj `CLAUDE.md`.
- [ ] **Krok 3:** `./test` → wszystkie 21 pakietów PASS, strażnik nie zgłasza importów. Na próbę dodaj `import SwiftUI` do `GetHomeUseCase.swift` i sprawdź, że `./test Domain/HomeUseCases` kończy się błędem strażnika; potem cofnij.
- [ ] **Krok 4:** Pełny plan testów Development na iPhone Duo → PASS; `BuildProject` dla obu schematów → OK.
- [ ] **Krok 5: Smoke (bramka G1), z użytkownikiem do logowania Apple:**
  1. Start po usunięciu aplikacji: alert zgody pojawia się raz, Home się ładuje.
  2. Zalogowanie, zabicie aplikacji i ponowny start: użytkownik dalej jest zalogowany (Review Focus 3).
  3. Ocena albumu: zmienia się średnia.
  4. Wybór odtwarzacza → Spotify: pokazuje się arkusz OAuth (Review Focus 5).
  5. Wylogowanie, potem usunięcie konta testowego: aplikacja wraca do trybu gościa.
- [ ] **Krok 6:** Commit `Run all logic tests on macOS with ./test`, otwórz PR 3.

---

## Wyniki fazy 0

**Spike A:** po dodaniu macOS do 10 pakietów `swift build Domain/HomeUseCases` przeszedł za pierwszym razem (75 s). Cały łańcuch zbudował się razem z Firebase 11.15.0 skompilowanym na macOS. `swift test`: HomeUseCases 7/7, HomeRepository 23/23. Firebase i MusicKit kompilują się na macOS, więc opcja B pytania 7 była wykonalna. Zostajemy przy opcji A, bo trzyma Firebase poza buildami `./test` i daje gwarancję w czasie kompilacji.

| Pakiet | Plik:linia | Błąd | Naprawia zadanie |
| --- | --- | --- | --- |
| SpotifyService | `SpotifyWebAuthSession.swift:37` | UIKit, `UIApplication.shared` | 1.6 |

**Spike B:** `NONCE-CHECK present=false matches=false` (Debug, symulator iPhone Duo, świeża instalacja). Log AuthKit pokazuje w samym żądaniu `nonce: (null)` i puste `requestedScopes`: `Task {}` w `onRequest` ustawia je dopiero po wysłaniu żądania. Firebase przyjął token mimo to. **Zadanie 0.4 jest potrzebne.**

Przy okazji: na symulatorze `getCredentialState` zaraz po zalogowaniu zwraca `AKAuthenticationError -7084` i splash wylogowuje użytkownika. Tak samo jest na `development`, więc to ograniczenie symulatora, nie regresja. Części G1 z logowaniem trzeba przejść na fizycznym iPhonie.

**Pomiar bazowy**

| Pomiar | Czas | Testy |
| --- | ---: | ---: |
| `xcodebuild test`, plan Development, drugi przebieg bez zmian | 213 s | 584 |
| `xcodebuild test` po zmianie w `GetHomeUseCase.swift` | 198 s | 584 |
| `swift test --package-path Core/Models`, drugi przebieg (po zadaniu 1.1) | 1,1 s | 46 |
