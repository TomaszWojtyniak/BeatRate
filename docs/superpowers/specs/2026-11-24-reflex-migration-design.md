# BeatRate → Reflex Architecture: plan migracji

**Data:** 2026-11-24
**Status:** zatwierdzony 2026-11-24: wszystkie rekomendacje (pytania 1–24) i decyzje M1–M9 przyjęte bez zmian; gotowy do planowania implementacji
**Źródło:** dokument w Claude Docs z diagramami: https://claude.ai/artifact/EkNGEhUd2u1EPzQHAiwJka
**Referencja architektury:** https://github.com/TomaszWojtyniak/ReflexArchitecture_iOS (`main` @ `befa64a`)

---

## TL;DR

Rekomendacja: przepisać BeatRate na Reflex **inkrementalnie, w 7 fazach (0–6)**, zachowując warstwy Clean Architecture (Presentation → Domain → Data → Services). Zmienia się głównie Presentation; Domain i Data zostają prawie bez zmian.

- **Co zostaje:** use case'y (\~1,1 tys. linii), repozytoria (\~1,0 tys.), logika serwisów (\~2,8 tys.), modele, design system (CoreUI) i 584 testy Swift jako siatka bezpieczeństwa.
- **Co się zmienia:** 13 DataModeli (\~1,7 tys. linii) staje się ViewModelami w kształcie Elm (`State` / `Action` / `Message` / `update`). Nawigacja (zakładki, stosy, arkusze, alerty) przechodzi z `@State` widoków do Core. Widoki (\~3,7 tys. linii) tylko czytają `state` i wysyłają akcje.
- **Co dochodzi:** `IntrospectionKit` (węzły dla `ls` / `do`), host `beatrate-cli` na fixturach, testy zachowania w Node (`behavior/`), serwer debug na `127.0.0.1:7777`, korzeń `BeatRateApp(edges:)`.
- **Warunek konieczny:** logika musi budować się na macOS bez UI i bez SDK. Spike z dziś: `Core/Models` z jedną linią `.macOS(.v27)` buduje się w \~10 s, a jego 43 testy przechodzą przez `swift test` w 4,4 s.
- **Największe ryzyka:** regresje w delikatnych przepływach (splash, logowanie, wylogowanie, usuwanie konta), koszt boilerplate'u na 16 ekranów i tarcie z bindingami SwiftUI (wyścig zapisu ścieżki nawigacji, znany z repo Reflex).
- **Rozmiar:** ok. 14–16 PR-ów. Czas skalibrujemy po pilocie (faza 2: korzeń + Splash), po którym jest bramka go/no-go.
- **Decyzje:** zatwierdzone 2026-11-24; wszystkie rekomendacje przyjęte bez zmian (ostatnia sekcja).

## Kontekst i cele

Cel: BeatRate ma działać według czterech filarów Reflex z [ReflexArchitecture\_iOS](https://github.com/TomaszWojtyniak/ReflexArchitecture_iOS), bez porzucania obecnego podziału na warstwy. Agent (Claude Code) i człowiek mają móc przejść całą aplikację z terminala oraz sterować działającą aplikacją w symulatorze bez stukania w piksele. Źródło koncepcji: [Reflex na blogu Shopify Engineering](https://shopify.engineering/reflex), cytowane w README repo.

**Cele**

- Logika (ViewModele, nawigacja, use case'y, repozytoria, logika serwisów) buduje się i testuje na macOS przez `swift build` / `swift test`, bez SwiftUI, UIKit, Firebase i MusicKit.
- Każdy ekran ma jeden kształt: `State` (Encodable), `Action`, `Message` i `update` jako jedyny zapis stanu.
- Każdy ekran jest węzłem introspekcji: nazwa, stan w JSON, lista akcji. Kontenery (zakładki, stos, arkusze) pożyczają akcje ekranowi na wierzchu.
- `./cli` (bez UI, na fixturach) i `nc localhost 7777` (Debug w symulatorze) mówią tym samym protokołem `ls` / `do`.
- Kluczowe podróże użytkownika mają testy zachowania, które działają bez sieci w sekundach.

**Nie-cele**

- Zmiany wyglądu, copy i UX. Migracja jest 1:1 (parity); wyjątki tylko jako nazwane decyzje z ostatniej sekcji.
- Zmiana backendu (Firebase RTDB, MusicKit, Spotify Web API) i schematu SwiftData.
- Wersja na Androida i makra `@Introspectable`; jak w repo, węzły pisane są ręcznie.

**Anty-cele (porażka, nawet jeśli „działa”)**

- Widok, który woła na ViewModelu coś innego niż odczyt `state` i `send(action:)`.
- Węzeł introspekcji z `if` albo z regułą, która należy do `update`.
- Test zachowania, który przechodzi mimo prawdziwego żądania sieciowego.
- Logika importująca SwiftUI, UIKit, Firebase lub MusicKit albo nie budująca się na macOS.
- Dwa grafy zależności naraz, np. dwa `HomeRepository` z osobnym cache'em `userId` po wylogowaniu.
- Serwer introspekcji w buildzie Release lub TestFlight.

**Ograniczenia**

- Toolchain na tym Macu: Xcode 27.2, Swift 6.4.2, macOS 27, Node 22.20, czyli to samo co w repo Reflex.
- iOS 27 i Swift 6 z `.defaultIsolation(MainActor.self)` w każdym pakiecie zostają.
- Po każdej fazie aplikacja musi dać się wydać z `development` (PR-y `task/…`).
- Przepływy ważne dla App Review (tryb gościa, usuwanie konta, działanie bez MusicKit) zachowują się identycznie.

## Obecna architektura BeatRate

BeatRate ma czyste warstwy poniżej Presentation, ale orkiestracja ekranów żyje w widokach. Widok tworzy DataModel, startuje ładowanie w `.task`, trzyma nawigację w `@State` i loguje analitykę w `.onAppear`.

| Warstwa | Pakiety | Linie kodu (bez testów) | Testy `@Test` | Jak wygląda dziś |
| --- | --: | --: | --: | --- |
| App | target aplikacji | 250 | 15 | `AppView` + `AppDataModel`: splash → wybór odtwarzacza → zakładki, arkusz logowania, alert zgody |
| Presentation | 10 | 5 383 (DataModele 1 695, widoki \~3 688) | 132 | `@Observable` DataModel tworzony w widoku z domyślnymi `.shared` |
| Domain | 8 | 1 123 | 65 | actory use case'ów za protokołami `Sendable` |
| Data | 9 (5 repozytoriów, 4 serwisy) | 3 833 | 248 | actory z `.shared`, cache SwiftData → Firebase → MusicKit |
| Core | 4 (Models, CoreApp, Analytics, CoreUI) | 3 096 | 124 | singletony sesji, odtwarzacza i analityki; design system |

**Co dziś blokuje Reflex**

1. **DataModele tworzą widoki.** 13 × `@State private var dataModel = …()`, 16 singletonów `static let shared` i 92 odwołania do `.shared` poza testami. Bez korzenia, który buduje graf, CLI nie ma czego uruchomić.
2. **Ładowanie zależy od cyklu życia widoku.** 14 × `.task` i 19 × `.onAppear`; samo `AlbumDetailsView.swift:106-123` ma cztery `.task` (ocena, kolory okładki, utwory, link odtwarzania). W terminalu nie ma `onAppear`, więc nic by się nie załadowało.
3. **Nawigacja w `@State` widoków.** 12 × `navigationDestination(item:)`, 7 × `.sheet`, 1 × `.fullScreenCover`, 3 × `.alert` (plus `errorAlert`) i `@Environment(\.dismiss)` w 7 widokach. Cykl AlbumDetails ↔ ArtistDetails jest obchodzony wstrzyknięciem `AnyView` (`AlbumDetailsView.swift:99`, `SearchView.swift:82`).
4. **Reguły w widokach.** Overlay dla gościa nad gwiazdkami i `Task.detached` przy zapisie oceny (`AlbumDetailsView.swift`), odczyt `MusicAuthorization.currentStatus` przy powrocie do aplikacji (`TabBarView.swift:43`), auto-prompt logowania (`AccountGuestView.swift:85`).
5. **Analityka ekranów rozsiana.** 17 × `track(.screenView…)` w `.onAppear` i 77 wywołań `track` / `log` łącznie.
6. **Frameworki przeciekają do logiki.** `import SwiftUI` w 22 plikach bez widoków (DataModele, use case'y, `LoginRepository`, modele, `SwiftDataManager`). `MusicAuthorization.Status` siedzi w publicznym `MusicAuthorizationResult`, a `AuthenticationServices` w DataModelach Login i Settings.
7. **Tylko iOS.** Wszystkie 31 pakietów deklarują `platforms: [.iOS(.v27)]`, więc `swift build` na macOS kompiluje dla macOS 12 i pada na SwiftData (sprawdziłem: 'Model()' is only available in macOS 14 or newer). Uwaga z CLAUDE.md o złych ścieżkach `.package(path:)` jest nieaktualna: sprawdziłem, wszystkie się rozwiązują.
8. **Crashlytics przyspawany do singletona.** `CrashLogger.shared` tworzy `FirebaseCrashBackend` w `static let` (`CrashLogger.swift:15`), a przez ten singleton idzie 113 wywołań `CrashLogger.log` / `report`.

**Co już jest dobre i zostaje**

- Szwy pod fixtury istnieją: `RealtimeDatabase` (w testach jest już `FakeRealtimeDatabase` na drzewie JSON), `AppleMusicDataSource`, `SpotifyTransport` (odpowiednik `HTTPClient` z repo), `AnalyticsBackend`, `CrashBackend`, `SwiftDataManager.inMemory()` i `credentialState` w `GetSplashUseCase`.
- Repozytoria i use case'y są za protokołami, a testy wstrzykują dublery przez `init` (konwencja Stub/Fake z CLAUDE.md).
- Komentarze w kodzie opisują dziesiątki przypadków brzegowych. To gotowa lista zachowań do testów (sekcja „Testy i weryfikacja”).
- `.environmentObject(cacheManager)` i `.modelContainer(…)` w `BeatRateApp.swift:22-23` nie mają odbiorców (zero `@EnvironmentObject` i `@Query`), więc ich usunięcie niczego nie psuje.

## Reflex Architecture: jak działa w repo

Reflex z repo to cztery filary: logika bez UI, ViewModel w stylu Elm, węzły introspekcji oraz CLI z testami zachowania. Nawigacja jest stanem Core, a nic nie czeka na cykl życia widoku.

| Filar | Jak działa w repo | Gdzie |
| --- | --- | --- |
| Core bez UI | Pakiet SwiftPM bez SwiftUI i UIKit, budowany przez `swift build` na macOS. Korzeń `InventoryApp(http:)` przyjmuje jedyną krawędź: klienta HTTP. | [InventoryApp.swift](https://github.com/TomaszWojtyniak/ReflexArchitecture_iOS/blob/main/Core/Sources/InventoryCore/InventoryApp.swift) |
| ViewModel jak w Elm | `State` (Encodable), publiczne `Action`, wewnętrzne `Message` (`.viewAction` + wyniki efektów), `update(state:message:)` jako jedyny zapis. Efekt to `Task`, który wraca przez `send(message:)`. | [ViewModel.swift](https://github.com/TomaszWojtyniak/ReflexArchitecture_iOS/blob/main/Core/Sources/InventoryCore/ViewModel.swift) |
| Węzły introspekcji | Węzeł = nazwa, stan jako JSON, akcje i `child`. Fokus to najgłębszy węzeł, a akcje zbierane są z całej ścieżki. Kontenery pożyczają akcje camelCase (`goBack`, `selectTab`, `dismiss`). | [IntrospectionSession.swift](https://github.com/TomaszWojtyniak/ReflexArchitecture_iOS/blob/main/Core/Sources/IntrospectionKit/IntrospectionSession.swift) |
| CLI i testy zachowania | `ls` i `do Akcja {json}` w trybie tekstowym i JSON. `inventory-cli` działa na fixturach, a `NetworkGuard` kończy proces kodem 3 przy żądaniu bez fixtury. Testy w Node bez zależności odpytują `ls` co 10 ms do 2 s. Ten sam protokół działa po TCP na porcie 7777 w Debug. | [sdk.mjs](https://github.com/TomaszWojtyniak/ReflexArchitecture_iOS/blob/main/behavior/sdk.mjs), [CLI.swift](https://github.com/TomaszWojtyniak/ReflexArchitecture_iOS/blob/main/Core/Sources/InventoryCLI/CLI.swift) |

**Reguły, które przenosimy 1:1**

- Jeśli użytkownik coś widzi, jest to w stanie. Jeśli może coś zrobić, jest to akcja. Każda akcja jest zawsze na liście, bez `if`, i tylko woła `send(action:)`.
- Przypadki brzegowe rozstrzyga `update`, nigdy widok ani węzeł.
- Nawigacja to stan Core: widok nigdy nie pushuje, tylko wysyła akcję.
- Ładowanie startuje w `init`, nie w `onAppear`.
- `StackView` ignoruje zdjęcie ekranu, który SwiftUI zna krócej niż 0,5 s. Przed tą poprawką ręczny test zgubił 2 ekrany na 30 szybkich podróży, po niej 0 na 120.
- Jedyny stan lokalny widoku w repo to bufor wpisywanej liczby.

**Zmierzona pętla w repo** (README, pomiary z 9–10.11.2026): podróż bez UI 13 ms, 14 testów w Node 0,73 s, `./test` po zmianie jednego pliku 4,6–11 s, ta sama zmiana w symulatorze 22,4 s.

**Czego repo nie rozwiązuje, a BeatRate potrzebuje**

- Jedna krawędź (HTTP) zamiast ok. 12: RTDB, Firebase Auth, MusicKit (katalog, autoryzacja, subskrypcja), Spotify HTTP i OAuth, Keychain, UserDefaults, SwiftData, Analytics, Crashlytics, stan Apple ID i czas.
- Efekty są fire-and-forget. BeatRate potrzebuje anulowania (debounce wyszukiwania, odświeżanie konta) i odrzucania nieaktualnych odpowiedzi.
- Jeden moduł Core zamiast 31 pakietów, więc trzeba ustalić, gdzie żyją `ViewModel`, `Route` i korzeń.
- Brak arkuszy z własnym stosem, alertów, systemowego przycisku Sign in with Apple i systemowych zgód.
- ViewModele są pokryte tylko podróżami, a CLAUDE.md BeatRate wymaga 100% pokrycia logiki testami Swift.

## Architektura docelowa: Reflex na warstwach Clean Architecture

Docelowo BeatRate ma trzy kręgi: hosty (aplikacja iOS, CLI, testy zachowania), Core bez UI z dzisiejszymi warstwami Clean Architecture oraz krawędzie, które host podaje do korzenia `BeatRateApp(edges:)`. Zależności idą w jedną stronę: hosty → Core → protokoły krawędzi.

```text
Hosty
  Aplikacja iOS                  widoki SwiftUI + CoreUI, Edges.live() z prawdziwymi SDK, serwer :7777 tylko w Debug
  beatrate-cli  <- behavior/     stdin/stdout (ls, do), Edges.fixtures() z plików JSON, żądanie bez fixtury -> exit 3
        |  oba hosty budują ten sam korzeń: BeatRateApp(edges:)
        v
Core bez UI (swift build i swift test na macOS)
  Presentation (logika)          tu zmienia się najwięcej
      AppRoot: BeatRateApp, AppNavigator, TabNavigator, StackNavigator, Route
      ViewModele: State, Action, Message, update + węzły introspekcji
  Domain                         use case'y bez zmian logiki
  Data                           repozytoria i logika serwisów nad szwami (RealtimeDatabase, SpotifyTransport, ModelContainer)
  Core                           Models (Encodable), CoreApp, Analytics z wymienialnymi backendami, IntrospectionKit
        |  protokoły (szwy)
        v
Krawędzie
  Adaptery …Live, tylko iOS      Firebase Auth i RTDB, MusicKit, Crashlytics, ASWebAuthenticationSession, Keychain, SwiftData
  Fixtury i fake'i, tylko CLI    FakeRealtimeDatabase, FakeMusicKitService, FakeSpotifyTransport, SwiftData w pamięci
```

Zmienia się głównie warstwa Presentation (logika). Domain, Data i Core zachowują logikę, a host decyduje tylko o tym, jakie krawędzie poda korzeniowi.

**Mapowanie warstw**

| Dziś | Docelowo | Buduje się na macOS |
| --- | --- | --- |
| `App/AppDelegate` (AppView, AppDataModel) | `App/` jest tylko hostem: `@State var app = BeatRateApp(edges: .live())`, `RootView`, serwer :7777 w Debug, `AppDelegate` z `FirebaseApp.configure()` | nie |
| `Presentation/TabBar` + `AppDataModel` + prezentacyjna część `SessionManager` | `Presentation/AppRoot`: target `AppRoot` (korzeń, `Screens`, `AppNavigator`, `TabNavigator`, `StackNavigator`, `Route`, węzły) i `AppRootUI` (`RootView`, `TabBarView`, `StackView` ze strażnikiem 0,5 s) | `AppRoot`: tak |
| `Presentation/<Feature>` (DataModel + widoki) | ten sam pakiet, dwa targety: `<Feature>` (ViewModel + `+Introspection.swift`) i `<Feature>UI` (widoki SwiftUI) | logika: tak |
| `Domain/*` | logika bez zmian; `import Foundation` zamiast SwiftUI, bez domyślnych `= .shared` | tak |
| `Data/Repositories/*` | logika bez zmian; bez `static let shared` | tak |
| `Data/Services/*` | `<Service>` (logika nad szwem) i `<Service>Live` (adapter SDK, tylko iOS) | logika: tak |
| `Core/Models` | `Encodable` dla stanu (`AlbumModel`, `HomeSection`, `MusicSearchResults`), `import Foundation` | tak |
| `Core/Analytics` | `Analytics` (eventy, menedżery, wymienialne backendy) i `AnalyticsFirebase` (backendy Firebase) | `Analytics`: tak |
| `Core/CoreApp` | bez zmian; menedżery tworzy korzeń, a nie `static let shared` | tak |
| `Core/CoreUI` | bez zmian (design system) | nie |
| — | nowe: `Domain/Composition` (`Edges`, `Graph`), `Core/IntrospectionKit` (z repo), `Tools/BeatRateCLI` (host + fixtury), `behavior/` (Node), skrypty `./cli` i `./test` | tak |

**Krawędzie: kto co podaje**

| Krawędź | Szew | Aplikacja iOS (`…Live`) | CLI (fixtura) |
| --- | --- | --- | --- |
| Firebase RTDB | `RealtimeDatabase` (jest) | `FirebaseRealtimeDatabase` | `FakeRealtimeDatabase` na drzewie JSON (jest w testach) |
| Firebase Auth | `AuthFirebaseServiceProtocol` (jest) | `AuthFirebaseService` | `FakeAuthService`: uid z fixtury |
| MusicKit: katalog, wyszukiwanie, ostatnio odtwarzane | `MusicKitServiceProtocol` (jest) | `MusicKitService` | `FakeMusicKitService`: `AppleMusicAlbumData` z JSON |
| MusicKit: autoryzacja i subskrypcja | jw., z własnym `MusicAccessStatus` zamiast `MusicAuthorization.Status` | jw. | status z fixtury |
| Spotify Web API | `SpotifyTransport` (jest) | `URLSessionTransport` | `FakeSpotifyTransport` (odpowiednik `FixtureHTTPClient` z repo) |
| Spotify OAuth | `WebAuthenticating` (nowy, nad `SpotifyWebAuthSession`) | `ASWebAuthenticationSession` | wynik z fixtury |
| Stan Apple ID | `credentialState` (jest, closure) | `ASAuthorizationAppleIDProvider` | stan z fixtury |
| Keychain | `AppleCredentialStore`, `AppleUserIDStore`, `SpotifyKeychain` (są) | `KeychainManager` | słownik w pamięci |
| UserDefaults | `UserDefaults` | `.standard` | `UserDefaults(suiteName:)` na proces |
| SwiftData | `ModelContainer` | plik na dysku | `SwiftDataManager.inMemory()` (jest) |
| Analytics, Crashlytics | `AnalyticsBackend`, `CrashBackend` (są) | Firebase | nagrywający backend, widoczny w węźle `Analytics` |
| Czas | `Duration` w `init` (jest: retry 2 s, debounce 0,5 s) | wartości produkcyjne | 0 ms albo `delayMs` z fixtury |
| Każde inne żądanie | — | — | `NetworkGuard` → exit 3 |

Zasada: każdy import SDK żyje w targecie `…Live` albo w `App/`. CLI nie linkuje Firebase ani MusicKit, więc przypadkowe użycie SDK w logice jest błędem kompilacji, a nie crashem w runtime.

## Co zostaje, co się zmienia, co znika

Zostaje cała logika domeny i danych oraz wygląd aplikacji. Zmienia się kształt warstwy prezentacji i sposób składania zależności. Znikają singletony, nawigacja w widokach i kod klejący, który ją obchodził.

| Moduł | Zostaje | Zmienia się | Znika |
| --- | --- | --- | --- |
| Domain (8 pakietów) | logika i protokoły use case'ów, 65 testów | `import Foundation` zamiast SwiftUI (6 plików), `.macOS(.v27)` | domyślne `= X.shared` w `init` |
| Data/Repositories (5) | cache trójpoziomowy, aktorzy, testy | `.macOS(.v27)`; `import SwiftUI` znika z `LoginRepository` | `static let shared` (5) |
| FirebaseService | `DatabaseFirebaseService` (oceny, agregaty, profil) nad `RealtimeDatabase` | `RealtimeDatabase` publiczny; nowy target `FirebaseServiceLive` (`FirebaseRealtimeDatabase`, `AuthFirebaseService`, `init` z `ASAuthorization`) | `shared` (2) |
| MusicKitService | protokół, mapowanie odpowiedzi API, testy | implementacja → `MusicKitServiceLive`; `MusicAccessStatus` zamiast `MusicAuthorization.Status` | `shared` |
| SpotifyService | sesja, klient, klasyfikator odpowiedzi, PKCE, testy | `SpotifyWebAuthSession` → `SpotifyServiceLive` | `shared` |
| SwiftDataManager | cały cache i wiersz sesji użytkownika | `import Foundation`; nie musi być `ObservableObject` | `shared`; `.environmentObject` i `.modelContainer` w `BeatRateApp.swift:22-23` |
| Models | wszystkie typy | `Encodable` dla `AlbumModel`, `HomeSection`, `MusicSearchResults`; `import Foundation` | — |
| Analytics | `AnalyticsEvent` (33 zdarzenia), `AnalyticsManager`, statyczne API `CrashLogger` (113 wywołań bez zmian) | backend `CrashLogger` wymienialny w runtime; backendy Firebase → `AnalyticsFirebase` | `AnalyticsManager.shared`; `FirebaseCrashBackend` wpisany na stałe w `CrashLogger.shared` |
| CoreApp | `SessionManager`, `MusicPlayerManager`, `UserDefaultsManager`, `KeychainManager`, `AppEnvironment` | instancje tworzy korzeń; prompt logowania przechodzi do `AppNavigator` | `shared` (4), prezentacyjna część `SessionManager` |
| CoreUI | design system, komponenty, `ArtworkColors` | `HomeSectionView` i `SectionAlbumsGridView` dostają `onSelect` zamiast `Binding<AlbumModel?>` | nieużywany `ViewFirstAppearModifier` |
| Presentation (10) | wygląd widoków, tokeny, lokalizacje | DataModel → ViewModel + węzeł; widok czyta `state` i wysyła akcje | nawigacja w `@State`, `AnyView`, `Task.detached`, analityka w `.onAppear` |
| App | `AppDelegate`, entitlements, plisty, schematy, plany testów | `@main` buduje korzeń i startuje serwer :7777 w Debug | `AppView`, `AppDataModel` |
| Testy | 584 testy jako punkt wyjścia, konwencja Stub/Fake | testy DataModeli → testy `update`; nowe podróże w `behavior/` | testy usuwanego kodu, w tym samym PR co jego zamiennik |

## Podejścia do migracji

Rekomenduję A: pełny Reflex wprowadzany inkrementalnie (strangler fig). Po każdej fazie aplikacja jest wydawalna, a pilot daje twarde dane, zanim wydamy większość budżetu.

| Podejście | Na czym polega | Zyski | Koszty i ryzyka |
| --- | --- | --- | --- |
| **A. Pełny Reflex, inkrementalnie** (rekomendacja) | 7 faz: fundament bez UI, korzeń + Splash (pilot), nawigacja w Core, ekrany po kolei, sprzątanie | aplikacja wydawalna po każdej fazie; bramka go/no-go po pilocie; podróże rosną razem z ekranami | przejściowy klej (trasy legacy, `AppGraph.current`); łącznie dłużej niż big bang |
| B. Big bang | cała warstwa Presentation przepisana na długiej gałęzi | brak kleju przejściowego; spójność od pierwszego dnia | tygodnie bez wydania; ogromny PR trudny do przeglądu; parity trudne do udowodnienia; konflikty z bieżącą pracą |
| C. Reflex-lite | tylko kształt ViewModelu i nawigacja w Core; bez CLI, introspekcji i macOS | najtańsze; czytelniejsze ekrany | traci główną wartość: agent nie steruje aplikacją i nie ma testów bez UI; w praktyce własna, lżejsza wersja TCA |

**Warianty wewnątrz A** (decyzje w ostatniej sekcji)

- **Graf zależności (pytanie 8).** Rekomenduję composition root już w fazie 1: korzeń buduje jeden graf, a stare DataModele biorą z niego zależności przez przejściowe `AppGraph.current`. Poważny powód: `HomeRepository` trzyma `userId` w pamięci przez 300 s, a `GetSplashUseCase.logout()` czyści go przez `invalidateUserCache()`. Przy dwóch instancjach druga pamiętałaby wylogowanego użytkownika do 5 minut, więc ocena mogłaby trafić na jego konto. Alternatywa to zostawienie singletonów i rejestrowanie krawędzi przy starcie.
- **Runner podróży (pytanie 16).** Rekomenduję Node + CLI jak w repo: osobny proces na test daje izolację i zero zależności. Alternatywa: Swift Testing w procesie przez `IntrospectionSession`, jeden język i pokrycie w Xcode.
- **Podział pakietów (pytanie 5).** Rekomenduję dwa targety w istniejącym pakiecie funkcji (`Home` i `HomeUI`), bo projekt Xcode zachowuje te same referencje do pakietów.

## Przykłady kodu: przed i po

Przykłady pokazują pełny pionowy wycinek głównej podróży: Home → AlbumDetails → ocena albumu. Nazwy typów i plików są propozycją; wygląd widoków i tokeny design systemu zostają bez zmian.

### 1. Pakiet funkcji po podziale

`Presentation/Home/Package.swift` dostaje drugi target. Logika buduje się na macOS, a widoki linkuje tylko aplikacja iOS.

```swift
// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "Home", targets: ["Home"]),      // ViewModel + węzeł introspekcji
        .library(name: "HomeUI", targets: ["HomeUI"]),  // widoki SwiftUI
    ],
    dependencies: [
        .package(path: "../../Core/Analytics"),
        .package(path: "../../Core/CoreUI"),
        .package(path: "../../Core/IntrospectionKit"),
        .package(path: "../../Core/Models"),
        .package(path: "../../Domain/HomeUseCases"),
        // AlbumDetails i Account znikają z zależności: nawigacją zajmuje się AppRoot
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: ["Analytics", "IntrospectionKit", "Models", "HomeUseCases"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "HomeUI",
            dependencies: ["Home", "CoreUI"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "HomeTests", dependencies: ["Home"]),
    ]
)
```

### 2. ViewModel: HomeDataModel → HomeViewModel

Dziś widok tworzy DataModel, startuje ładowanie i trzyma nawigację:

```swift
public struct HomeView: View {
    @State private var dataModel: HomeDataModel = HomeDataModel()   // → GetHomeUseCase() → HomeRepository.shared
    @State private var selectedAlbum: AlbumModel?

    public var body: some View {
        ZStack { /* switch dataModel.state */ }
            .navigationDestination(item: $selectedAlbum) { AlbumDetailsView(album: $0) }
            .onChange(of: selectedAlbum) { _, album in if let album { dataModel.trackHomeAlbumTap(album) } }
            .onAppear { dataModel.track(.screenView(.home)) }
            .task(priority: .userInitiated) { await dataModel.loadInitialData() }
    }
}
```

Po migracji cała ta logika jest w jednym `update`. Protokół `ViewModel` to 10 linii skopiowanych z repo jako `internal` w każdym module logiki, więc widok fizycznie nie zawoła `update` ani `send(message:)`.

```swift
// Presentation/Home/Sources/Home/HomeViewModel.swift
import Analytics
import HomeUseCases
import Models
import Observation

@Observable
public final class HomeViewModel: ViewModel {
    public struct State: Encodable {
        public enum Phase: String, Encodable { case loading, ready, failed, empty }
        public var phase = Phase.loading
        public var sections: [HomeSection] = []
        public var isRefreshing = false
    }

    public enum Action {
        case openAlbum(id: String)
        case seeAll(section: String)
        case refresh
        case retry
    }

    enum Message {
        case viewAction(Action)
        case loaded([HomeSection])
        case loadFailed
    }

    public internal(set) var state = State()
    private let getHome: any GetHomeUseCaseProtocol
    private let setHome: any SetHomeUseCaseProtocol
    private let analytics: AnalyticsManager
    private let crashLogger: CrashLogger
    private let openAlbum: (AlbumModel) -> Void
    private let openSection: (HomeSection) -> Void

    /// Ładuje od razu: bez cyklu życia widoku CLI zachowuje się jak aplikacja.
    init(getHome: any GetHomeUseCaseProtocol, setHome: any SetHomeUseCaseProtocol,
         analytics: AnalyticsManager, crashLogger: CrashLogger,
         openAlbum: @escaping (AlbumModel) -> Void, openSection: @escaping (HomeSection) -> Void) {
        self.getHome = getHome
        self.setHome = setHome
        self.analytics = analytics
        self.crashLogger = crashLogger
        self.openAlbum = openAlbum
        self.openSection = openSection
        fetch()
    }

    public func send(action: Action) { send(message: .viewAction(action)) }

    func update(state: inout State, message: Message) {
        switch message {
        case .loaded(let sections):
            state.sections = sections
            state.phase = sections.isEmpty ? .empty : .ready
            state.isRefreshing = false
        case .loadFailed:
            // Co już jest na ekranie, wygrywa: nieudane odświeżenie nie czyści feedu.
            state.phase = state.sections.isEmpty ? .failed : .ready
            state.isRefreshing = false
        case .viewAction(.retry):
            analytics.log(.retryTap(screen: .home))
            state.phase = .loading
            fetch()
        case .viewAction(.refresh):
            analytics.log(.pullToRefresh(screen: .home))
            state.isRefreshing = true
            Task {
                try? await setHome.clearCache()   // nieudane czyszczenie i tak przeładowuje
                fetch()
            }
        case .viewAction(.openAlbum(let id)):
            guard let section = state.sections.first(where: { $0.albums.contains { $0.id == id } }),
                  let album = section.albums.first(where: { $0.id == id }) else { return }
            analytics.log(.albumTap(source: .homeSection, albumId: id, section: section.analyticsName))
            openAlbum(album)
        case .viewAction(.seeAll(let name)):
            guard let section = state.sections.first(where: { $0.name == name }) else { return }
            openSection(section)
        }
    }

    /// Efekt: wynik wraca do `update` jako nowa wiadomość.
    private func fetch() {
        Task {
            do {
                send(message: .loaded(try await getHome.fetchHomeSections()))
            } catch {
                CrashLogger.log("Failed to fetch sections: \(error)", to: .home)
                crashLogger.reportToCrashlytics(error: error)
                send(message: .loadFailed)
            }
        }
    }
}
```

Konwencja, której repo nie mówi wprost: `update` nigdy nie woła `send(message:)` synchronicznie na tym samym ViewModelu. Zagnieżdżony zapis `state` skończy się utratą zmian albo pułapką exclusivity w runtime, dlatego efekty idą przez `Task` (tu: `fetch()`).

### 3. Węzeł introspekcji

```swift
// Presentation/Home/Sources/Home/HomeViewModel+Introspection.swift
import IntrospectionKit

extension HomeViewModel: IntrospectionProviding {
    public var introspectionNode: any IntrospectionNode { Node(viewModel: self) }

    private struct Node: IntrospectionNode {
        let viewModel: HomeViewModel
        let name = "Home"
        var state: any Encodable { viewModel.state }
        var actions: [IntrospectionAction] {
            [
                IntrospectionAction("OpenAlbum", input: AlbumIdInput.self) { viewModel.send(action: .openAlbum(id: $0.id)) },
                IntrospectionAction("SeeAll", input: SectionInput.self) { viewModel.send(action: .seeAll(section: $0.section)) },
                IntrospectionAction("Refresh") { viewModel.send(action: .refresh) },
                IntrospectionAction("Retry") { viewModel.send(action: .retry) },
            ]
        }
    }
}

nonisolated struct AlbumIdInput: IntrospectionInput {
    let id: String
    static let fields = ["id"]
}

nonisolated struct SectionInput: IntrospectionInput {
    let section: String
    static let fields = ["section"]
}
```

Oczekiwany wynik po fazie 4 (ilustracja, nie zrzut):

```text
$ printf 'ls\ndo OpenAlbum {"id":"1440935467"}\nls\n' | ./cli behavior/fixtures/device.signedIn.json behavior/fixtures/catalog.discovery.json
Home
  state   {"isRefreshing":false,"phase":"ready","sections":[{"albums":[…],"analyticsName":"New Releases",…}]}
  actions OpenAlbum {id}, SeeAll {section}, Refresh, Retry, goBack, selectTab {tab}
ok
AlbumDetails
  state   {"hasLoadedRating":true,"isLoggedIn":true,"myRating":0,"savedRating":0,…}
  actions Rate {rating}, OpenArtist, ToggleTracklist {expanded}, Play, goBack, selectTab {tab}
```

### 4. Widok po migracji

```swift
// Presentation/Home/Sources/HomeUI/HomeView.swift
import CoreUI
import Home
import SwiftUI

public struct HomeView: View {
    let viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) { self.viewModel = viewModel }

    public var body: some View {
        let state = viewModel.state
        ZStack {
            switch state.phase {
            case .loading: HomeLoadingView()
            case .empty: HomeEmptyView { viewModel.send(action: .retry) }
            case .failed: HomeFailedView { viewModel.send(action: .retry) }
            case .ready:
                ScrollView {
                    GlassEffectContainer(spacing: Spacing.md) {
                        LazyVStack(spacing: Spacing.md) {
                            ForEach(state.sections) { section in
                                HomeSectionView(
                                    name: section.sectionName,
                                    albums: section.albums,
                                    onSelect: { viewModel.send(action: .openAlbum(id: $0.id)) },
                                    onSeeAll: { viewModel.send(action: .seeAll(section: section.name)) }
                                )
                                .padding(Spacing.lg)
                                .roundedMaterialBackground()
                                .padding(.horizontal, Spacing.md)
                            }
                        }
                        .padding(.bottom, Spacing.lg)
                    }
                }
                .meshBackground()
                .refreshable {
                    viewModel.send(action: .refresh)
                    // .refreshable chce async: czekamy na Core, żeby wskaźnik nie zniknął od razu
                    for await refreshing in Observations({ viewModel.state.isRefreshing }) where !refreshing { break }
                }
                .softScrollEdges()
            }
        }
        .navigationTitle(String(localized: .homeNavigationTitle))
        .toolbarTitleDisplayMode(.inlineLarge)
        // Bez .task, .onAppear, .onChange i .navigationDestination: to wszystko jest w Core.
    }
}
```

`HomeLoadingView`, `HomeEmptyView` i `HomeFailedView` to dzisiejsze gałęzie `HomeView` wydzielone bez zmian wyglądu.

### 5. AlbumDetails: optymistyczna ocena z cofnięciem

To najważniejsza reguła głównej podróży. Dziś jest rozłożona na widok (overlay dla gościa, `Task.detached`, flaga `hasLoadedInitialRating`) i DataModel; po migracji to jedno `update`.

```swift
public struct State: Encodable {
    public var album: AlbumModel
    public var myRating: Double = 0        // co pokazują gwiazdki
    public var savedRating: Double = 0     // co jest zapisane; do tej wartości cofamy
    public var hasLoadedRating = false
    public var isLoggedIn: Bool
    public var player: MusicPlayer?
    public var playUrl: URL?
    public var lastSave: SaveResult?       // na to reaguje błysk „Zapisano” w widoku
    public enum SaveResult: String, Encodable { case saved, removed, failed }
}

public enum Action {
    case rate(Double)                      // ostateczna wartość gwiazdek; 0 usuwa ocenę
    case openArtist
    case toggleTracklist(expanded: Bool)
    case play
}

enum Message {
    case viewAction(Action)
    case ratingLoaded(Double?)
    case saved(Double, refreshed: AlbumModel?)
    case saveFailed
    case session(isLoggedIn: Bool)
}

func update(state: inout State, message: Message) {
    switch message {
    case .viewAction(.rate(let rating)):
        guard state.isLoggedIn else {
            // Gość widzi gwiazdki, ale ocenić nie może. Decyduje Core, nie overlay w widoku.
            analytics.log(.rateLoginRequiredTap(albumId: state.album.id))
            requestLogin(.rating)
            return
        }
        // Przed wczytaniem oceny albo przy tej samej wartości zapis kosztowałby przeliczenie średniej.
        guard state.hasLoadedRating, rating != state.savedRating else { return }
        state.myRating = rating                                   // optymistycznie
        analytics.log(.rateAlbum(albumId: state.album.id, rating: rating))
        let id = state.album.id
        let metadata = (artist: state.album.appleMusicAlbumData.artist, title: state.album.appleMusicAlbumData.title)
        Task {   // Task trzyma ViewModel, więc zapis kończy się także po zamknięciu ekranu
            do {
                try await details.saveAlbumRating(albumId: id, rating: rating, albumMetadata: metadata)
                let refreshed = (try? await details.getUpdatedAlbum(albumId: id)) ?? nil
                send(message: .saved(rating, refreshed: refreshed))
            } catch {
                CrashLogger.report("RateAlbum", "error saving album: \(error)", to: .albumDetails)
                send(message: .saveFailed)
            }
        }
    case .saved(let rating, let refreshed):
        state.savedRating = rating
        state.lastSave = rating == 0 ? .removed : .saved
        if let refreshed { state.album = refreshed }             // nowa średnia z cache
    case .saveFailed:
        state.myRating = state.savedRating                       // gwiazdki wracają
        state.lastSave = .failed
    case .ratingLoaded(let rating):
        state.myRating = rating ?? 0
        state.savedRating = rating ?? 0
        state.hasLoadedRating = true
    case .session(let isLoggedIn):
        // Gość, który zalogował się z promptu, zostaje na ekranie, więc link odtwarzania liczymy od nowa.
        state.isLoggedIn = isLoggedIn
        state.playUrl = Self.playUrl(album: state.album, player: state.player, isLoggedIn: isLoggedIn)
    case .viewAction(.openArtist), .viewAction(.toggleTracklist), .viewAction(.play):
        break   // analityka + zamknięcia z korzenia, jak openAlbum w Home
    }
}
```

W widoku znika `.allowsHitTesting(isLoggedIn)` z overlayem i `Task.detached`. Gwiazdki wysyłają tylko wartość końcową, a podgląd przeciągania zostaje lokalnym stanem widoku (pytanie 14).

```swift
RateAlbumView(rating: state.myRating, feedback: state.lastSave) { viewModel.send(action: .rate($0)) }
```

### 6. Nawigacja w Core

`StackNavigator` i `StackView` ze strażnikiem 0,5 s kopiujemy z repo. Nowe są `Route` z ekranami BeatRate i `Screens`, czyli jedyne miejsce, które zna wszystkie ekrany.

```swift
// Presentation/AppRoot/Sources/AppRoot/Route.swift
/// Ekran na stosie, porównywany po tożsamości obiektu, więc nadaje się na element ścieżki SwiftUI.
nonisolated public enum Route: Hashable {
    case home(HomeViewModel)
    case search(SearchViewModel)
    case account(AccountViewModel)
    case accountGuest(AccountGuestViewModel)
    case sectionGrid(SectionGridViewModel)
    case albumDetails(AlbumDetailsViewModel)
    case artistDetails(ArtistDetailsViewModel)

    public static func == (lhs: Route, rhs: Route) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var id: ObjectIdentifier {
        switch self {
        case .home(let viewModel): ObjectIdentifier(viewModel)
        case .albumDetails(let viewModel): ObjectIdentifier(viewModel)
        // … pozostałe przypadki tak samo
        }
    }
}
```

```swift
// Presentation/AppRoot/Sources/AppRoot/Screens.swift
/// Ekran dostaje funkcje, nie nawigator. AlbumDetails i ArtistDetails nie importują się
/// nawzajem, więc znika wstrzykiwanie `AnyView` z AlbumDetailsView i SearchView.
struct Screens {
    let graph: Graph
    let requestLogin: (LoginPromptReason) -> Void

    func home(on stack: StackNavigator) -> HomeViewModel {
        HomeViewModel(
            getHome: graph.getHome, setHome: graph.setHome,
            analytics: graph.analytics, crashLogger: graph.crashLogger,
            openAlbum: { [weak stack] album in
                guard let stack else { return }
                stack.push(.albumDetails(albumDetails(.album(album), on: stack)))
            },
            openSection: { [weak stack] section in
                guard let stack else { return }
                stack.push(.sectionGrid(sectionGrid(section, on: stack)))
            }
        )
    }

    func albumDetails(_ source: AlbumDetailsViewModel.Source, on stack: StackNavigator) -> AlbumDetailsViewModel {
        AlbumDetailsViewModel(
            source: source, details: graph.getAlbumDetails, albumById: graph.getAlbumById,
            session: graph.session, players: graph.players, analytics: graph.analytics,
            requestLogin: requestLogin,
            openArtist: { [weak stack] albumId in
                guard let stack else { return }
                stack.push(.artistDetails(artistDetails(.albumId(albumId), on: stack)))
            }
        )
    }
}
```

```swift
// Presentation/AppRoot/Sources/AppRoot/TabNavigator.swift (fragment)
nonisolated public enum MainTab: String, CaseIterable, Encodable, Sendable { case home, search, account }

func update(state: inout State, message: Message) {
    switch message {
    case .viewAction(.selectTab(let tab)):
        guard tab != state.selected else {
            stack(for: tab).send(action: .popTo(depth: 0))   // ponowny tap: pierwszy ekran zakładki
            return
        }
        state.selected = tab
        analytics.log(.tabSelected(tab: tab.rawValue))
        stack(for: tab).focus()   // ekran na wierzchu dostaje .focused: pierwsze ładowanie, odświeżenie, screen_view
    case .musicAccessChecked(let granted):
        // Po sceneBecameActive korzeń sprawdza status MusicKit. Home i Search stoją na katalogu
        // Apple Music, Account zostaje dostępne (App Review 5.1.1(v)).
        state.hasMusicAccess = granted
    }
}
```

### 7. Korzeń, krawędzie i dwa hosty

Korzeń to ten sam kod w obu hostach; różnią się tylko krawędzie. `Graph` żyje w nowym pakiecie `Domain/Composition`, poniżej Presentation, żeby stare DataModele mogły czytać `Graph.current` do czasu swojej migracji.

```swift
// Presentation/AppRoot/Sources/AppRoot/BeatRateApp.swift
/// Korzeń drzewa obiektów. Aplikacja iOS i CLI to dwa hosty, które go budują.
public final class BeatRateApp {
    public let navigator: AppNavigator

    public init(edges: Edges) {
        CrashLogger.shared.use(edges.crash)   // 113 statycznych wywołań zostaje bez zmian
        let graph = Graph(edges: edges)       // serwisy → repozytoria → use case'y, jeden raz na proces
        Graph.current = graph                 // ponytail: tylko dla starych DataModeli, znika w fazie 6
        navigator = AppNavigator(graph: graph)
    }
}

extension BeatRateApp: IntrospectionProviding {
    // ponytail: korzeń nic nie pożycza, więc jego węzłem jest węzeł nawigatora (jak w repo)
    public var introspectionNode: any IntrospectionNode { navigator.introspectionNode }
}
```

```swift
// Domain/Composition/Sources/Composition/Edges.swift
/// Wszystko poza logiką aplikacji. Aplikacja iOS podaje prawdziwe SDK, CLI fixtury.
public struct Edges {
    public var database: any RealtimeDatabase
    public var auth: any AuthFirebaseServiceProtocol
    public var music: any MusicKitServiceProtocol
    public var spotifyTransport: any SpotifyTransport
    public var spotifyWebAuth: any WebAuthenticating
    public var keychain: any KeychainBackend
    public var appleIDState: @Sendable (String) async -> AppleIDCredentialState
    public var defaults: UserDefaults
    public var modelContainer: ModelContainer
    public var analytics: any AnalyticsBackend
    public var crash: any CrashBackend
    public var retryDelay: Duration = .seconds(2)
    public var searchDebounce: Duration = .milliseconds(500)
}
```

```swift
// Domain/Composition/Sources/Composition/Graph.swift (fragment)
/// Jeden graf na proces: jeden HomeRepository, jeden SwiftDataManager, jedna sesja.
public final class Graph {
    public static var current: Graph!   // ponytail: przejściowe dla starych DataModeli, faza 6 usuwa

    public let analytics: AnalyticsManager
    public let session: SessionManager
    public let getHome: any GetHomeUseCaseProtocol
    // … pozostałe use case'y

    public init(edges: Edges) {
        let keychain = KeychainManager(backend: edges.keychain)
        let swiftData = SwiftDataManager(container: edges.modelContainer, appleUserIDStore: keychain)
        let database = DatabaseFirebaseService(database: edges.database)
        let spotify = SpotifyService(transport: edges.spotifyTransport, webAuth: edges.spotifyWebAuth, keychain: keychain)
        let music = MusicRepository(musicKitService: edges.music, spotifyService: spotify)
        let home = HomeRepository(databaseFirebaseService: database, musicRepository: music, swiftDataManager: swiftData)
        analytics = AnalyticsManager(defaults: edges.defaults, backend: edges.analytics)
        session = SessionManager()
        getHome = GetHomeUseCase(homeRepository: home)
        // …
    }
}
```

```swift
// App/BeatRateMain.swift — host iOS (dzisiejszy BeatRateApp.swift)
@main
struct BeatRateMain: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var app = BeatRateApp(edges: .live())   // .live() najpierw woła FirebaseApp.configure()
    #if DEBUG
    @State private var server: IntrospectionServer?
    #endif

    var body: some Scene {
        WindowGroup {
            RootView(navigator: app.navigator)
            #if DEBUG
                .task { startServer() }   // jak w repo: tylko Debug, tylko 127.0.0.1:7777
            #endif
        }
    }
}
```

Uwaga na kolejność: dziś Firebase konfiguruje `AppDelegate`, a pierwsze żądania startują z `.task` widoku. W Reflex korzeń powstaje razem z `@State`, przed `didFinishLaunching`, a ładowanie rusza w `init`. Dlatego `FirebaseApp.configure()` przenosimy na początek `Edges.live()`.

```swift
// Tools/BeatRateCLI/Sources/BeatRateCLI/CLI.swift — host bez UI
@main
enum CLI {
    static func main() async throws {
        let fixtures = try Fixtures.load(Array(CommandLine.arguments.dropFirst()))
        NetworkGuard.install()
        let session = IntrospectionSession(root: BeatRateApp(edges: .fixtures(fixtures)))
        // Asynchroniczne czytanie pozwala efektom (Task) działać między komendami.
        for try await line in FileHandle.standardInput.bytes.lines where !line.isEmpty {
            let answer = session.handle(line)
            if !NetworkGuard.violations.isEmpty {
                fail(NetworkGuard.violations.map { "network violation: \($0)" }.joined(separator: "\n"), code: 3)
            }
            FileHandle.standardOutput.write(Data((answer + "\n").utf8))   // bez bufora, jak w repo
        }
    }
}
```

### 8. Fixtury i fałszywe krawędzie

Jeden format pliku z sekcjami `db`, `music`, `http` i `device`. Sesja ładuje kilka małych plików, a przy tym samym kluczu wygrywa późniejszy; w `db` scalamy drzewo aż do liści. `db` ma kształt eksportu RTDB z konsoli Firebase.

`behavior/fixtures/catalog.discovery.json`:

```json
{
  "db": {
    "sections": {
      "s1": { "id": "1", "name": "New Releases", "name_pl": "Nowości", "albums": ["1440935467"], "isActive": true }
    },
    "albums": {
      "1440935467": { "artist": "Daft Punk", "title": "Discovery", "avgRating": 8.5, "ratingCount": 2 }
    },
    "album_ratings": { "1440935467": { "u2": 8, "u3": 9 } }
  },
  "music": {
    "authorization": "authorized",
    "albums": {
      "1440935467": { "id": "1440935467", "title": "Discovery", "artist": "Daft Punk", "coverUrl": null, "releaseDate": null, "genre": "Electronic" }
    }
  }
}
```

`behavior/fixtures/device.signedIn.json`:

```json
{
  "device": {
    "firebaseUid": "u1",
    "keychain": { "appleUserID": "apple-1" },
    "appleIDState": "authorized",
    "loggedInUserId": "u1",
    "defaults": { "analyticsConsent": true, "mainMusicPlayer.u1": "appleMusic" }
  }
}
```

- `title` i `artist` w `db` i `music` muszą się zgadzać: `HomeRepository.validateAlbumData` odrzuca album z rozjazdem, a sekcja po cichu go pomija.
- Zapis do `db` zmienia drzewo w pamięci, więc podróż widzi średnią przeliczoną przez prawdziwy `DatabaseFirebaseService` z `album_ratings`.
- `FakeRealtimeDatabase` przenosimy z `FirebaseServiceTestDoubles.swift` do targetu `FirebaseServiceFakes`, żeby ten sam fake służył testom serwisu i CLI.
- Brak fixtury dla żądania (`music.albums`, `http`) to naruszenie: CLI kończy się kodem 3, jak w repo.

Fixtura może też wymusić błąd albo opóźnienie ścieżki RTDB (`dbFailures`, `dbDelayMs`), na wzór `failingReads` i `failingWrites` z dzisiejszego `FakeRealtimeDatabase` oraz `delayMs` z repo. Tego potrzebują punkty 3, 9 i 13 listy parity.

### 9. Podróż zachowania (Node)

```js
// behavior/rating.test.mjs
import assert from 'node:assert/strict';
import test from 'node:test';
import { createBehaviorSession, fixture } from './sdk.mjs';

async function openDiscovery(session) {
  await session.precondition('Home', ({ state }) => assert.equal(state.phase, 'ready'));
  await session.do({
    action: 'OpenAlbum',
    payload: { id: '1440935467' },
    expectation: ({ name, state }) => {
      assert.equal(name, 'AlbumDetails');
      assert.equal(state.hasLoadedRating, true);
    },
  });
}

test('a signed-in user rates an album and its average follows', async (t) => {
  const session = createBehaviorSession({ fixtures: [fixture('device.signedIn'), fixture('catalog.discovery')] });
  t.after(() => session.close());
  await openDiscovery(session);

  await session.do({
    action: 'Rate',
    payload: { rating: 9 },
    expectation: ({ state }) => {
      assert.equal(state.lastSave, 'saved');
      assert.equal(state.album.firebaseAlbumData.ratingCount, 3);
      assert.equal(state.album.firebaseAlbumData.avgRating, (8 + 9 + 9) / 3);
    },
  });
});

test('a guest who taps the stars is asked to sign in, for rating', async (t) => {
  const session = createBehaviorSession({ fixtures: [fixture('device.guest'), fixture('catalog.discovery')] });
  t.after(() => session.close());
  await openDiscovery(session);

  await session.do({
    action: 'Rate',
    payload: { rating: 7 },
    expectation: ({ name, state }) => {
      assert.equal(name, 'LoginPrompt');
      assert.equal(state.reason, 'rating');
    },
  });
});
```

Przypadki „nic się nie dzieje” (ta sama ocena nie zapisuje) idą do testów jednostkowych. Oczekiwanie prawdziwe już przed akcją niczego nie dowodzi, co repo zapisuje jako regułę.

### 10. Test przejścia `update` (Swift Testing)

```swift
// Presentation/AlbumDetails/Tests/AlbumDetailsTests/AlbumDetailsViewModelTests.swift
import Models
import Testing
@testable import AlbumDetails

@MainActor
struct AlbumDetailsViewModelTests {
    private let details = StubGetAlbumDetailsUseCase()

    @Test func `failed save puts the stars back on the saved rating`() {
        let viewModel = AlbumDetailsViewModel.make(details: details, isLoggedIn: true)
        var state = viewModel.state
        state.savedRating = 6
        state.myRating = 9

        viewModel.update(state: &state, message: .saveFailed)

        #expect(state.myRating == 6)
        #expect(state.lastSave == .failed)
    }

    @Test(arguments: [(0.0, AlbumDetailsViewModel.State.SaveResult.removed), (9.0, .saved)])
    func `a confirmed save reports what happened to the rating`(rating: Double, result: AlbumDetailsViewModel.State.SaveResult) {
        let viewModel = AlbumDetailsViewModel.make(details: details, isLoggedIn: true)
        var state = viewModel.state

        viewModel.update(state: &state, message: .saved(rating, refreshed: nil))

        #expect(state.savedRating == rating)
        #expect(state.lastSave == result)
    }
}
```

Testy przejść są czyste: nie czekają na `Task`. Efekty sprawdzamy podróżami albo stubem z licznikiem (`saveCount`), zgodnie z konwencją Stub z CLAUDE.md. `make(details:isLoggedIn:)` to fabryka w `AlbumDetailsTestDoubles.swift`.

### 11. Efekt z anulowaniem: wyszukiwanie z debounce

```swift
// Presentation/Search/Sources/Search/SearchViewModel.swift (fragment)
/// ponytail: uchwyt efektu, nie stan ekranu. Jedyne pole ViewModelu poza `State`.
private var searchTask: Task<Void, Never>?

func update(state: inout State, message: Message) {
    switch message {
    case .viewAction(.queryChanged(let query)):
        state.query = query
        searchTask?.cancel()
        guard !query.isEmpty else {
            state.albums = []
            state.artists = []
            state.isSearching = false
            return
        }
        state.isSearching = true
        searchTask = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let results = try? await search.search(searchTerm: query)
            send(message: .searchFinished(query: query, results: results))
        }
    case .searchFinished(let query, let results):
        guard query == state.query else { return }   // nieaktualna odpowiedź: użytkownik pisał dalej
        state.isSearching = false
        state.albums = results?.albums ?? []
        state.artists = results?.artists ?? []
        if let results { analytics.log(.search(albumCount: results.albums.count, artistCount: results.artists.count)) }
    // …
    }
}
```

W widoku `.searchable` dostaje binding, którego `set` wysyła akcję:

```swift
.searchable(text: Binding(get: { viewModel.state.query },
                          set: { viewModel.send(action: .queryChanged($0)) }))
```

### 12. CrashLogger z wymienialnym backendem

```swift
// Core/Analytics/Sources/Analytics/Logger/CrashLogger.swift (fragment)
import Synchronization

@MainActor
public final class CrashLogger {
    /// Domyślnie tylko OSLog. Aplikacja iOS podmienia backend na Crashlytics, CLI na nagrywający.
    nonisolated public static let shared = CrashLogger(backend: OSLogCrashBackend())

    nonisolated private let backend: Mutex<any CrashBackend>

    nonisolated public init(backend: any CrashBackend) {
        self.backend = Mutex(backend)
    }

    nonisolated public func use(_ backend: any CrashBackend) {
        self.backend.withLock { $0 = backend }
    }
    // log / report / setValue czytają backend przez withLock; 113 wywołań w kodzie bez zmian
}
```

`FirebaseCrashBackend` i `FirebaseAnalyticsBackend` przechodzą bez zmian do targetu `AnalyticsFirebase`, który linkuje tylko aplikacja iOS.

## Plan działania krok po kroku

Plan ma 7 faz (0–6) i bramkę po każdej; najważniejsza jest G2, czyli go/no-go po pilocie. Każdy krok to osobny PR na gałęzi `task/reflex-…` z zielonym `BuildProject` i testami.

```text
Faza 0  Decyzje i spike'i                 G0  decyzje podjęte, spike'i zielone albo blokery znane
Faza 1  Fundament bez UI                  G1  aplikacja działa identycznie; swift test zielony dla całej logiki; zero SDK w logice
Faza 2  Reflex: korzeń i Splash (pilot)   G2  GO/NO-GO: podróże startu zielone; ./test po zmianie <= 30 s; koszt ekranu zmierzony
Faza 3  Nawigacja w Core                  G3  aplikacja nawigowalna z ./cli i nc; 0 zgubionych ekranów na 120 podróży
Faza 4  Główna podróż                     G4  punkty parity 7–10 zielone; druga kalibracja kosztu ekranu
Faza 5  Pozostałe ekrany                  G5  zero DataModeli; każdy punkt listy parity ma test
Faza 6  Sprzątanie i dokumentacja         G6  cele z tabeli liczb osiągnięte albo odstępstwa nazwane
```

Bramka G2 decyduje, czy wydajemy resztę budżetu: po pilocie znamy realny koszt ekranu i czas pętli zwrotnej.

### Faza 0 · Decyzje i spike'i

Cel: zamknąć pytania z ostatniej sekcji i sprawdzić dwa założenia, na których stoi plan.

1. Odpowiedzi w arkuszu decyzji. Po akceptacji ten dokument trafia do repo jako `docs/superpowers/specs/2026-11-24-reflex-migration-design.md` (zrobione 2026-11-24).
2. Spike A (wyrzucana gałąź): `.macOS(.v27)` w łańcuchu Models → CoreApp → Analytics → SwiftDataManager → FirebaseService → HomeRepository → HomeUseCases, z wydzielonymi `FirebaseServiceLive` i `AnalyticsFirebase`. Cel: `swift test` zielony dla `HomeRepository` na macOS bez Firebase w grafie.
3. Spike B: log `request.nonce` w `LoginPromptView` (Debug) i sprawdzenie claimu `nonce` w tokenie Apple (pytanie 24).
4. Pomiar bazowy: czas `xcodebuild test` planu Development na iPhone Duo, do porównania z `swift test`.

**Gotowe, gdy:** arkusz wypełniony, spike A zielony albo znamy blokery, czas bazowy zapisany. **Rozmiar:** 0 PR-ów produkcyjnych.

### Faza 1 · Fundament bez UI (zero zmian zachowania)

Cel: cała logika buduje się i testuje na macOS, a graf zależności powstaje w jednym miejscu.

1. `.macOS(.v27)` w pakietach logiki: Models, CoreApp, Analytics, 8 × Domain, 5 × Repositories, 4 × Services.
2. `import SwiftUI` → `import Foundation` w 22 plikach logiki; `Encodable` dla `AlbumModel`, `HomeSection` i `MusicSearchResults`.
3. Targety `…Live`: `FirebaseServiceLive`, `MusicKitServiceLive` (+ `MusicAccessStatus`), `SpotifyServiceLive` (web auth za `WebAuthenticating`) i `AnalyticsFirebase`; `CrashLogger` z `use(_:)`.
4. `Domain/Composition`: `Edges` i `Graph(edges:)`, a `Edges.live()` w `App/`. Poza CrashLogger.shared usuwamy 15 × `static let shared` i domyślne `= .shared`; stare DataModele biorą zależności z `Graph.current`.
5. Usunięcie `.environmentObject` i `.modelContainer` z `BeatRateApp.swift:22-23` oraz nieużywanego `ViewFirstAppearModifier`.
6. Skrypt `./test` (na razie `swift test` po kolei w pakietach logiki) i aktualizacja CLAUDE.md.

**Gotowe, gdy (G1):** aplikacja zachowuje się identycznie (smoke QA: start gościa, logowanie, ocena, wylogowanie, usunięcie konta testowego); wszystkie testy są zielone w `swift test` i w planie testów Xcode; `grep` nie znajduje SwiftUI, UIKit, Firebase ani MusicKit w targetach logiki. **Rozmiar:** 2–3 PR-y (platformy i importy; targety `…Live`; composition root).

### Faza 2 · Infrastruktura Reflex i pilot: korzeń + Splash

Cel: pierwsza podróż od startu aplikacji do zakładek działa bez UI i na żywo.

1. `Core/IntrospectionKit`: kopia z repo bez zmian API, razem z jego 6 testami Swift (2 testy NetworkGuard z repo przechodzą do CLI).
2. `Tools/BeatRateCLI`: host stdin/stdout, `Fixtures` (db, music, http, device), `NetworkGuard`, `Edges.fixtures(_:)` i skrypt `./cli`.
3. `behavior/`: `sdk.mjs` z repo i `fixtures/`; `./test` dostaje build CLI i `node --test 'behavior/*.test.mjs'`.
4. `Presentation/AppRoot`: `BeatRateApp(edges:)` i `AppNavigator` (fazy splash → wybór odtwarzacza → zakładki, arkusz logowania, alert zgody analityki, obserwacja stanu logowania) z węzłem `App`. Zakładki są w tej fazie dzisiejszym `TabBarView` jako liściem legacy.
5. `SplashViewModel`: maszyna stanów z `SplashDataModel` (credentials → explainer MusicKit → autoryzacja → odtwarzacz → Spotify → cache → pobranie z 3 ponowieniami), węzły `Splash` i `MusicExplainer`, stan jako enumy (pytanie 13).
6. `IntrospectionServer` na 127.0.0.1:7777 w Debug.
7. Podróże: gość z `notDetermined` → explainer → Continue → zakładki; odmowa MusicKit → zakładki w trybie ograniczonym; unieważnione Apple ID → pełne wylogowanie; 3 nieudane pobrania → wejście do aplikacji; alert zgody przy pierwszym starcie.

**Gotowe, gdy (G2, go/no-go):** podróże startu są zielone bez UI i przez `nc`; `./test` po zmianie jednego pliku logiki trwa ≤ 30 s; koszt ekranu jest zmierzony (czas, linie) i ekstrapolowany na pozostałe 12 DataModeli. **Rozmiar:** 3 PR-y (infrastruktura i CLI; korzeń; Splash).

### Faza 3 · Nawigacja w Core

Cel: cała aplikacja jest nawigowalna z `./cli` i `nc`, zanim ekrany przejdą na ViewModele.

1. `TabNavigator` (home, search, account; ponowny tap → pierwszy ekran; dostęp MusicKit po `sceneBecameActive`), 3 × `StackNavigator`, `Route`, `Screens` i `StackView` ze strażnikiem z repo.
2. Arkusze i alerty jako stan nawigatorów: Settings z własnym stosem (wybór odtwarzacza, usuwanie konta), Favorites, EditProfile, Share (`fullScreenCover`), prompt logowania, alerty wylogowania i czyszczenia ostatnich albumów.
3. Stare ekrany jako trasy legacy: zamiast `navigationDestination(item:)` i `.sheet` dostają zamknięcia (`onOpenAlbum`, `onOpenArtist`, …) od `Screens`, a wstrzykiwanie `AnyView` znika.
4. Fokus ekranu: `screen_view` z nawigacji (pytanie 10) i komunikat `.focused` do ekranu na wierzchu.
5. `behavior/live/navigation-race.mjs` dla trzech zakładek.

**Gotowe, gdy (G3):** `ls` pokazuje każdy ekran (legacy jako węzeł z nazwą, bez akcji); 0 zgubionych ekranów na 120 szybkich podróży; liczby `screen_view` w scenariuszu kontrolnym zgadzają się z dzisiejszymi. **Rozmiar:** 2 PR-y (zakładki i stosy; arkusze i alerty).

### Faza 4 · Główna podróż: przeglądanie i ocena

1. `HomeViewModel`, `SectionGridViewModel`, `AlbumDetailsViewModel` (połączony z `AlbumDetailsContainer`) i `ArtistDetailsViewModel` z węzłami i widokami `…UI`.
2. Komponenty CoreUI z `onSelect` zamiast `Binding<AlbumModel?>`.
3. Podróże: feed → album → ocena → nowa średnia; usunięcie oceny (0); błąd zapisu → cofnięcie gwiazdek; gość → prompt `rating`; zapis kończy się po `goBack` (fixtura z `delayMs`); album → artysta → album.
4. Usunięcie 4 DataModeli i ich testów po przeniesieniu przypadków do testów `update`.

**Gotowe, gdy (G4):** punkty parity 7–10 zielone; druga kalibracja kosztu ekranu. **Rozmiar:** 2 PR-y.

### Faza 5 · Pozostałe ekrany

Kolejność: Search (debounce, ostatnie albumy) → LoginPrompt (nonce w stanie) → wybór odtwarzacza (onboarding i zmiana) → AccountGuest i Account (Favorites, EditProfile, Share) → Settings (wylogowanie, usuwanie konta).

**Gotowe, gdy (G5):** zero DataModeli; każdy punkt listy parity ma test; QA palcem przepływów systemowych (Sign in with Apple, prompt MusicKit, OAuth Spotify, `ShareLink`). **Rozmiar:** 4–5 PR-ów.

### Faza 6 · Sprzątanie i dokumentacja

1. Usunięcie `Graph.current`, tras legacy, prezentacyjnej części `SessionManager` i pozostałego kleju.
2. CLAUDE.md, skill `.claude/skills/reflex/SKILL.md` dla BeatRate, AGENTS.md i README (sekcja „Zmiany w dokumentacji i konwencjach”).
3. Pomiary końcowe wobec liczb wyjściowych (sekcja „Testy i weryfikacja”).

**Gotowe, gdy (G6):** cele z tabeli liczb osiągnięte albo odstępstwa nazwane. **Rozmiar:** 1 PR.

## Testy i weryfikacja

Weryfikujemy na pięciu poziomach. Stary DataModel znika dopiero wtedy, gdy każdy jego punkt z listy parity ma test w nowym świecie.

| Poziom | Co sprawdza | Narzędzie | Kiedy |
| --- | --- | --- | --- |
| Testy jednostkowe Swift | przejścia `update` (także no-opy), use case'y, repozytoria, serwisy | `swift test` per pakiet na macOS; plan testów w Xcode | każdy PR |
| Podróże zachowania | ścieżki użytkownika na fixturach, zero sieci | `./test` → `node --test 'behavior/*.test.mjs'` | każdy PR od fazy 2 |
| Na żywo | te same akcje na symulatorze, wyścigi nawigacji | `nc localhost 7777`, `node behavior/live/navigation-race.mjs` | zmiany nawigacji, przed bramką |
| QA palcem | gesty, animacje, przepływy systemowe (arkusz Apple, prompt MusicKit, OAuth Spotify, `ShareLink`) | iPhone Duo, urządzenie | przed bramką |
| Build | oba schematy iOS | Xcode MCP `BuildProject` (wymóg CLAUDE.md) | każdy PR |

**Lista parity: zachowania, które muszą przetrwać migrację**

| # | Zachowanie | Źródło dziś | Test docelowo |
| --: | --- | --- | --- |
| 1 | Gość przy starcie nie czyści cache; poprawność poświadczeń sprawdzamy tylko u zalogowanych | `SplashDataModel.loadInitialData()` | podróż |
| 2 | Odmowa MusicKit nie blokuje startu; Home i Search pokazują ekran braku dostępu, Account działa (App Review 5.1.1(v)) | `SplashDataModel.continueAfterMusicKitGate()`, `TabBarScreen.isAvailable` | podróż |
| 3 | Po 3 nieudanych pobraniach aplikacja i tak wchodzi do zakładek | `SplashDataModel.handleMaxRetriesReached` | podróż (fixtura z błędem RTDB) |
| 4 | Weryfikacja Spotify nigdy nie blokuje startu ani nie wylogowuje | `SplashDataModel`, krok 4 | podróż |
| 5 | Unieważnione Apple ID oznacza pełne wylogowanie, identyczne z ręcznym | `GetSplashUseCase.forceLogout()` | podróż + istniejące testy use case'u |
| 6 | Wiersz logowania odbudowany po resecie magazynu SwiftData | `GetSplashUseCase.restoreLoginFromDurableState()` | istniejący test + podróż |
| 7 | Nieudane odświeżenie Home zostawia feed; pusty backend to nie awaria | `HomeDataModel.resolveState` | test `update` |
| 8 | Ocena 0 usuwa ocenę, ta sama wartość nie zapisuje, błąd zapisu cofa gwiazdki | `AlbumDetailsDataModel.saveAlbumRating`, `HomeRepository.saveAlbumRating` | podróż + test `update` |
| 9 | Zapis oceny kończy się po zamknięciu ekranu | `Task.detached` w `AlbumDetailsView` | podróż (`delayMs`, `goBack`, ponowne otwarcie) |
| 10 | Gość dotykający gwiazdek dostaje prompt z powodem `rating`; po zalogowaniu na tym samym ekranie pojawia się przycisk odtwarzania | `AlbumDetailsView` (overlay, `.task(id: isLoggedIn)`) | podróż |
| 11 | Account pokazuje prompt raz na sesję i nie po celowym wylogowaniu | `SessionManager.autoPromptForAccountIfNeeded()`, `userDidLogout()` | podróż |
| 12 | Średnia ocen w Account od 5 ocen; ulubione maks. 4; udostępnianie tylko z 4 | `AccountDataModel.average`, `maxFavorites` | test `update` |
| 13 | Zapis ulubionych optymistyczny, po błędzie resync z serwera | `AccountDataModel.saveFavorites` | podróż (fixtura z błędem zapisu) |
| 14 | Pull-to-refresh w Account nie zmienia ekranu, dopóki nie przyjdą wszystkie dane | `AccountDataModel.fetchAllData` | test `update` |
| 15 | Powrót do Account odświeża tylko ocenione albumy | `AccountView.swift:165` | podróż (fokus) |
| 16 | Zmiana odtwarzacza w Settings przeładowuje „ostatnio słuchane” w Account | `AccountView.swift:174` | podróż |
| 17 | „Ostatnio słuchane” ze Spotify tylko dla konta Premium | `AccountDataModel.recentsPlayer` | test `update` |
| 18 | Wyszukiwanie: debounce 500 ms, nieaktualne wyniki odrzucone, ostatni album na górze listy | `SearchDataModel` | test `update` + podróż |
| 19 | Analityka dopiero po zgodzie; alert przy pierwszym starcie; cofnięcie zgody resetuje dane | `AnalyticsManager.setConsent`, `AppView` | podróż (węzeł `Analytics`) |
| 20 | Odtwarzacz zapisany dopiero po udanym połączeniu; odmowa Apple Music pokazuje przejście do Ustawień | `MusicPlayerPickerDataModel.select` | podróż |
| 21 | Usunięcie konta wymaga ponownego Sign in with Apple; anulowanie nie jest błędem | `SettingsDataModel.deleteAccount`, `verifyErrorMessage` | podróż |
| 22 | Ponowny tap zakładki wraca do jej pierwszego ekranu | dziś system, w Reflex `TabNavigator` | podróż |

**Definicja ukończenia każdego PR-a**

- `BuildProject` zielony dla obu schematów (Xcode MCP; CLI `xcodebuild` jako zapas).
- `./test` zielony: `swift test` w pakietach logiki, build CLI i podróże, zero naruszeń sieci.
- Zmieniony ekran: węzeł ma akcję na każdy przypadek `Action`, bez `if`.
- Pokrycie modułu sprawdzone (`xccov` albo `llvm-cov`), luki nazwane w opisie PR-a.
- Punkty parity ekranu mają wskazany test (numer z tabeli w opisie PR-a).
- Zmiany nawigacji: `navigation-race.mjs` daje 0 zgubionych ekranów na 120.

**Automatyczni strażnicy architektury (w `./test`)**

- `grep -rE '^import (SwiftUI|UIKit|Firebase|MusicKit)'` po źródłach targetów logiki zwraca pusto.
- Widoki nie widzą `update` ani `send(message:)`, bo protokół `ViewModel` jest `internal`; pilnuje tego kompilator.
- Binarka Release nie zawiera `IntrospectionServer` (`nm` albo `strings` na buildzie Release).
- `./cli` z brakującą fixturą kończy się kodem 3 (test samego SDK, jak `sdk.test.mjs` w repo).

**Liczby wyjściowe i cele**

| Miara | Dziś | Cel |
| --- | --: | --: |
| Testy `@Test` w Swift | 584 | ≥ 584 (zastępowane, nie kasowane) |
| Podróże zachowania | 0 | ≥ 22 (lista parity) |
| DataModele | 13 | 0 |
| `static let shared` | 16 | 1 (`CrashLogger.shared`) |
| Odwołania do `.shared` poza testami | 92 | ≈ 0 (poza `CrashLogger.shared`) |
| `import SwiftUI` w logice | 22 | 0 |
| `.task` + `.onAppear` w widokach | 33 | ≤ 3 (np. `ArtworkColors`, render karty w `FavoritesShareView`) |
| Prezentacja sterowana `@State` widoku (`navigationDestination`, `.sheet`, `.fullScreenCover`) | 20 | 0 |
| Czas testów logiki | do zmierzenia w fazie 0 (`xcodebuild test`) | `swift test`; dziś Models: 43 testy w 4,4 s |
| Czas jednej podróży | — | < 1 s |

**Scenariusz QA na żywo (przed każdą bramką)**

1. `printf 'ls\n' | nc -w 1 127.0.0.1 7777` na buildzie Debug w symulatorze pokazuje ekran z fokusem.
2. `do OpenAlbum {"id":"…"}`, `do Rate {"rating":8}`, `do goBack`, `do selectTab {"tab":"account"}`: ekran podąża za komendami.
3. To samo palcem: ocena przeciąganiem, pull-to-refresh, swipe-back, zamknięcie arkusza gestem.
4. `node behavior/live/navigation-race.mjs` daje 0 zgubionych ekranów.

## Plusy i minusy

Największy plus to agent, który sprawdza zachowanie aplikacji w milisekundach bez symulatora. Największy minus to koszt przepisania 13 DataModeli i więcej kodu na każdy ekran.

| Obszar | Plus | Minus |
| --- | --- | --- |
| Weryfikacja przez agenta | Claude Code przechodzi aplikację przez `ls` / `do` bez UI, a na żywo przez :7777, bez zrzutów ekranu i stukania w piksele | protokół i węzły trzeba utrzymywać razem z ekranami; ekran bez węzła to ślepy punkt |
| Pętla zwrotna | podróż bez UI trwa milisekundy; `swift test` na macOS (Models: 43 testy w 4,4 s) zamiast symulatora | pierwszy build CLI i buildy po zmianach w wielu pakietach trwają dłużej niż w jednopakietowym repo Reflex |
| Testy | przejścia `update` testuje się bez czekania; fixtury dają powtarzalne stany (MusicKit odmówiony, sesja Spotify wygasła, brak sieci) | dwa runnery (Swift i Node), JavaScript w repo iOS; podróże nie liczą się do pokrycia Swift (pytanie 17) |
| Spójność ekranów | jeden kształt dla 16 ekranów; każda reguła w jednym `update` | więcej typów na ekran: `State`, `Action`, `Message`, `update` i plik `+Introspection` (szacunkowo +30–60 linii na ekran) |
| Nawigacja | stan Core: znika `AnyView`, deep link i ponowny tap zakładki to akcje, nawigację da się testować | wyścig zapisu ścieżki SwiftUI wymaga strażnika 0,5 s z repo; arkusze z własnym stosem są nowością względem repo |
| Widoki | widok tylko czyta stan i wysyła akcje, więc praca z design systemem jest prostsza | tarcie z API SwiftUI opartym na bindingach: `.searchable`, `.refreshable`, przeciąganie gwiazdek, zamykanie arkuszy gestem |
| Współbieżność | wyścigi opisane dziś w komentarzach (splash kontra `AppDataModel`, `-999` przy pull-to-refresh) stają się jawnymi komunikatami | efekty nie mają wbudowanego anulowania; potrzebna konwencja `Task` + strażnik nieaktualnej odpowiedzi |
| Architektura | porty i adaptery na krawędziach; kompilator gwarantuje brak Firebase i MusicKit w logice; jeden graf zależności | więcej pakietów i targetów (`…Live`, `…UI`, `Composition`, `IntrospectionKit`, CLI); przejściowe `Graph.current` |
| Analityka | `screen_view` z jednego miejsca zamiast 17 × `.onAppear`; zdarzenia da się sprawdzać w podróżach | moment logowania zdarzeń zmienia się subtelnie, więc liczby w Firebase mogą drgnąć (pytanie 10) |
| Wydajność | znikają nadmiarowe `.task` przy przełączaniu gałęzi widoku | `state` to jedna właściwość: każda zmiana unieważnia całe `body`, które ją czyta, więc duże widoki trzeba dzielić na podwidoki z wartościami |
| Ryzyko produktowe | fazy i lista parity chronią przepływy ważne dla App Review | możliwe regresje w starcie, logowaniu i usuwaniu konta, gdzie komentarze opisują dawne błędy |
| Koszt | inwestycja wraca przy każdej nowej funkcji (szablon ekranu + podróż) | ok. 14–16 PR-ów; \~1,7 tys. linii DataModeli do przepisania i \~3,7 tys. linii widoków do dostosowania |

## Ryzyka i mitygacje

Trzy ryzyka mają wysoki wpływ i realną szansę: regresja w przepływach startu i logowania, dwa grafy zależności w okresie przejściowym i kolejność startu Firebase. Wszystkie trzy mitygujemy, zanim ruszy pierwszy ekran.

| Ryzyko | Szansa | Wpływ | Mitygacja | Sygnał ostrzegawczy |
| --- | --- | --- | --- | --- |
| Regresja w starcie, logowaniu, wylogowaniu lub usuwaniu konta | średnia | wysoki | Splash jako pilot; lista parity; podróże przed usunięciem starego kodu; QA palcem przed G2 i G5 | czerwona podróż; nowe non-fatale w Crashlytics po wydaniu |
| Dwa grafy zależności naraz (np. stary `userId` w drugim `HomeRepository`) | średnia | wysoki | composition root w fazie 1, jedno `Graph.current`, test na to, że korzeń i stare ekrany dostają tę samą instancję | dwie instancje w Memory Graph Debuggerze |
| Kolejność startu Firebase: korzeń powstaje przed `didFinishLaunching` | średnia | wysoki | `FirebaseApp.configure()` na początku `Edges.live()`; podróż na żywo zaraz po starcie | crash „FirebaseApp not configured” przy pierwszym uruchomieniu |
| Wyścig zapisu ścieżki `NavigationStack` (znany z repo) | wysoka | średni | strażnik 0,5 s ze `StackView` bez zmian; `navigation-race.mjs` po każdej zmianie nawigacji | zgubione ekrany w teście na żywo |
| Logika nie buduje się na macOS (Firebase, MusicKit, UIKit w zakamarkach) | niska dzięki `…Live` | średni | spike A w fazie 0; `#if canImport(UIKit)` tylko tam, gdzie osobny target to przesada | błąd `swift build` |
| Grubsze odświeżanie widoków (jeden `state`) | średnia | niski–średni | `Equatable` fragmenty stanu, podwidoki przyjmujące wartości, Instruments na Home i Account | spadek płynności przewijania |
| Boilerplate spowalnia pracę | wysoka | średni | szablon ekranu i skill `reflex`; pilot mierzy koszt przed bramką G2 | PR ekranu trwa dłużej, niż zakłada kalibracja z G2 |
| Fixtury rozjeżdżają się z produkcją (kształt RTDB, odpowiedzi MusicKit) | średnia | średni | `db` jako fragment eksportu RTDB; testy serwisów zostają; przegląd fixtur przy zmianach schematu | podróż zielona, a produkcja pada |
| Teksty w CLI (String Catalogs przy `swift build`) | średnia | niski | w stanie enumy zamiast tekstów (pytanie 13), tłumaczy widok | w `ls` klucze zamiast tekstów |
| Serwer introspekcji trafia do Release | niska | wysoki | `#if DEBUG`, tylko 127.0.0.1, strażnik na binarce Release w `./test` | `strings` znajduje `IntrospectionServer` |
| Zmiana liczb w analityce | średnia | niski–średni | decyzja w pytaniu 10; porównanie dashboardu tydzień przed i po wydaniu fazy 3 | skok liczby `screen_view` |
| Długa migracja blokuje nowe funkcje | średnia | średni | fazy wydawalne; nowe ekrany od razu w Reflex; bez zamrażania funkcji | rosnąca kolejka PR-ów |

## Zmiany w dokumentacji i konwencjach

Najwięcej zmienia się CLAUDE.md, bo to on uczy agenta pracy w repo. Dochodzi skill `reflex` dla BeatRate, a DesignSystem.md dostaje jeden akapit o widokach w Reflex.

| Plik | Zmiana | Faza |
| --- | --- | --- |
| `CLAUDE.md` → Build & Run | usunąć „swift test does not work” i uwagę o ścieżkach; dodać `./test`, `./cli`, `nc localhost 7777` | 1, 2 |
| `CLAUDE.md` → Architecture | warstwy z Reflex: hosty, Core bez UI, krawędzie; reguła „SDK tylko w `…Live` i `App/`” | 1, 3 |
| `CLAUDE.md` → Adding a New Feature Screen | nowy przepis: (1) podróż w `behavior/`, (2) ViewModel w `<Feature>`, (3) `+Introspection.swift`, (4) trasa w `AppRoot`, (5) widok w `<Feature>UI` z tokenami, (6) testy `update` | 2 |
| `CLAUDE.md` → Unit Tests | testy przejść `update`; no-opy jednostkowo, ścieżki podróżami; polityka pokrycia z pytania 17; nazwy `Fake…` dla krawędzi CLI, zgodnie z obecną konwencją Stub/Fake | 2 |
| `CLAUDE.md` → Verifying changes | po `BuildProject` także `./test`, a przy zmianach nawigacji `navigation-race.mjs` | 2 |
| `.claude/skills/reflex/SKILL.md` | adaptacja skilla z repo: uruchamianie, reguły węzła, dodawanie fixtury, ekranu i podróży, sterowanie na żywo | 2 |
| `AGENTS.md` | skill `reflex` w tabeli skilli | 2 |
| `Core/CoreUI/DesignSystem.md` | akapit „Widok w Reflex”: czyta `state`, wysyła akcje; lista dozwolonego stanu lokalnego z pytania 14 | 3 |
| `README.md` | sekcja „Aplikacja bez UI”: `./cli`, fixtury, `./test` | 2 |
| `docs/superpowers/specs/`, `plans/` | ten dokument po akceptacji jako spec; plan na każdą fazę w formacie istniejącego `2026-08-30-spotify-service-refactor.md` | 0 |

## Decyzje (zatwierdzone 2026-11-24)

Wszystkie 24 rekomendacje oraz decyzje M1–M9 przyjęto bez zmian. Przy każdym pytaniu obowiązuje opcja z linii „Rekomendacja”; arkusz na końcu to zapis odpowiedzi.

### A. Zakres i strategia

1. **Którą strategią migrujemy?**
   - A: pełny Reflex inkrementalnie, 7 faz, aplikacja wydawalna po każdej.
   - B: big bang na długiej gałęzi.
   - C: Reflex-lite (kształt ViewModelu i nawigacja, bez CLI i introspekcji).
   - Rekomendacja: **A**. B nie daje się bezpiecznie przejrzeć, a C traci sterowanie przez agenta, czyli główny powód migracji.
2. **Czy akceptujesz kryteria bramki go/no-go po fazie 2?**
   - Kryteria: podróże startu zielone bez UI i przez `nc`; `./test` po zmianie jednego pliku logiki ≤ 30 s; koszt ekranu zmierzony i ekstrapolowany; zero regresji w testach Swift.
   - Do ustalenia: czy próg 30 s Ci pasuje i jaki koszt oznacza „stop” (np. zmiana ekranu ponad 2× dłuższa niż dziś).
   - Rekomendacja: przyjąć kryteria, a próg kosztu ustalić po pomiarze bazowym w fazie 0.
3. **Jakie zmiany zachowania dopuszczamy w migracji?**
   - A: tylko 1:1, żadnych zmian.
   - B: 1:1 plus nazwane wyjątki zatwierdzone tutaj: `screen_view` z nawigacji (pytanie 10), ładowanie zakładek przy pierwszym fokusie (pytanie 11), poprawka nonce (pytanie 24).
   - C: swobodnie, przy okazji poprawiamy UX.
   - Rekomendacja: **B**. Każdy wyjątek ma osobną decyzję, więc parity da się sprawdzić.
4. **W jakiej kolejności migrujemy ekrany po pilocie?**
   - A: główna podróż (Home, SectionGrid, AlbumDetails, ArtistDetails), potem Search, LoginPrompt, wybór odtwarzacza, Account i Settings.
   - B: najpierw Account i Settings, bo mają najwięcej logiki sesji.
   - Rekomendacja: **A**. Ocena albumu to rdzeń produktu i najlepszy test wartości Reflex, a Account i Settings skorzystają z gotowych już wzorców.

### B. Struktura modułów

5. **Jak dzielimy pakiety Presentation?**
   - A: dwa targety w istniejącym pakiecie (`Home` i `HomeUI`).
   - B: osobne pakiety (`Presentation/Home` i `Presentation/HomeUI`).
   - C: jeden duży pakiet Core z całą logiką, jak w repo Reflex.
   - Rekomendacja: **A**. Referencje w projekcie Xcode zostają, a C łamie modułowość, którą chcesz zachować.
6. **Czy zmieniamy nazwy `…DataModel` na `…ViewModel`?**
   - A: tak, bo zmienia się kontrakt typu, a postęp łatwo policzyć (`*DataModel.swift` → 0).
   - B: nie, zostaje `DataModel` w nowym kształcie.
   - Rekomendacja: **A**.
7. **Gdzie trzymamy kod SDK?**
   - A: w targetach `…Live` (Firebase, MusicKit, web auth Spotify, Analytics); CLI nie linkuje SDK.
   - B: SDK zostaje w logice, dodajemy tylko macOS; CLI linkuje Firebase, ale go nie woła.
   - Rekomendacja: **A**. B to wolniejszy build CLI, niesprawdzona kompilacja Firebase na macOS i crash zamiast błędu kompilacji przy przypadkowym użyciu.
8. **Jak składamy graf zależności?**
   - A: composition root od fazy 1 (`Graph(edges:)`), `.shared` znika, stare DataModele czytają przejściowe `Graph.current`.
   - B: zostawiamy singletony, a krawędzie rejestruje host przy starcie; sprzątanie na końcu.
   - Rekomendacja: **A**. Jeden graf od pierwszego dnia, bez ryzyka dwóch `HomeRepository`; B zostawia globalny stan do samego końca i blokuje testy w procesie.
9. **Gdzie żyje protokół `ViewModel`?**
   - A: 10-liniowa kopia `internal` w każdym module logiki, jak w repo; widok fizycznie nie zawoła `update`.
   - B: jeden publiczny protokół w `Core/IntrospectionKit`; wtedy `update` i `Message` muszą być publiczne.
   - Rekomendacja: **A**. Kilkanaście kopii po 10 linii to mniejsze ryzyko niż publiczne `update`.

### C. Konwencje Reflex w BeatRate

10. **Skąd bierzemy `screen_view`?**
    - A: z nawigacji w Core: zdarzenie przy każdym zyskaniu fokusu (wejście, powrót z ekranu, zamknięcie arkusza).
    - B: widok wysyła akcję `.appeared` w `.onAppear`, a ViewModel loguje.
    - Rekomendacja: **A**. Jedno miejsce zamiast 17, działa w CLI i da się sprawdzić w podróży. Semantyka jest najbliższa dzisiejszemu `.onAppear`, ale liczby mogą lekko drgnąć.
11. **Kiedy ładują się zakładki Search i Account?**
    - A: przy starcie, w `init`, czysto jak w repo; więcej ruchu sieciowego przy każdym starcie.
    - B: przy pierwszym fokusie zakładki, o którym decyduje `TabNavigator`; dzisiejszy ruch sieciowy zostaje.
    - Rekomendacja: **B**. Decyzja nadal należy do Core, a gość nie płaci za odczyt profilu przy starcie.
12. **Jak ekrany dowiadują się o zmianie sesji (zalogowanie, odtwarzacz)?**
    - A: korzeń rozsyła komunikat `.session(…)` do żywych ekranów.
    - B: każdy ViewModel subskrybuje `Observations` na `SessionManager`.
    - C: widok czyta `SessionManager` bezpośrednio.
    - Rekomendacja: **A**. Jawne i testowalne, bez długożyjących zadań w każdym ekranie; C łamie regułę „wszystko, co widać, jest w stanie”.
13. **Czy w stanie trzymamy teksty, czy znaczenia?**
    - A: enumy znaczeniowe (np. `.retrying(attempt: 2, of: 3, reason: .noData)`), a widok tłumaczy je na tekst.
    - B: gotowe `String(localized:)` w ViewModelu, jak dziś.
    - Rekomendacja: **A**. `ls` i podróże nie zależą od języka, a lokalizacja zostaje w warstwie UI.
14. **Czy akceptujesz listę wyjątków od „wszystko w `State`”?**
    - Lista: podgląd przeciągania gwiazdek, błysk „Zapisano” (1,4 s), kolory okładki z `ArtworkColors`, render karty i `ShareLink`, `openURL`.
    - Rekomendacja: **tak**, i nic poza tą listą bez nowej decyzji.
15. **Czy włączamy `NonisolatedNonsendingByDefault` i `InferIsolatedConformances` jak w repo?**
    - A: nie w tej migracji, osobny PR później.
    - B: tak, razem z fazą 1.
    - Rekomendacja: **A**. Pierwsza flaga zmienia semantykę asynchronicznych funkcji `nonisolated` w aktorach repozytoriów; to osobne ryzyko.

### D. Testy

16. **Czym uruchamiamy podróże zachowania?**
    - A: Node + CLI jak w repo: proces na test, zero zależności, przenośne między platformami.
    - B: Swift Testing w procesie przez `IntrospectionSession`: jeden język i pokrycie w Xcode.
    - C: oba.
    - Rekomendacja: **A**. Zgodne z repo i izolowane; B można dodać później, bo graf na instancję korzenia na to pozwala.
17. **Jak liczymy pokrycie, skoro CLAUDE.md wymaga 100%?**
    - A: 100% pokrycia logiki zostaje dla testów Swift (przejścia `update` testowane jednostkowo), a podróże są ponad to.
    - B: pokrycie łączone z `swift test` i przebiegów CLI (`llvm-cov`), więc podróż może zastąpić test jednostkowy.
    - C: jak w repo: ViewModele pokrywają tylko podróże.
    - Rekomendacja: **A** na start i sprawdzenie B w pilocie. A nie zmienia kultury testów; B usunie dublowanie, jeśli scalanie profili zadziała.
18. **Czy akceptujesz format fixtur?**
    - Jeden plik JSON z sekcjami `db` (fragment eksportu RTDB), `music`, `http` i `device`; pliki są scalane, późniejszy wygrywa.
    - Rekomendacja: **tak**.
19. **Co robimy ze starymi testami DataModeli?**
    - A: kasujemy w PR-ze migracji ekranu, po przeniesieniu ich przypadków do testów `update` lub podróży.
    - B: zostawiamy do końca fazy 6.
    - Rekomendacja: **A**. Testy usuniętego kodu niczego nie chronią, a lista parity pilnuje, żeby przypadki nie zginęły.
20. **Czy podróże mają działać w Xcode Cloud?**
    - A: na start lokalnie i u agenta, w CI po fazie 4 (Node trzeba doinstalować w `ci_scripts/ci_post_clone.sh`).
    - B: od razu w CI.
    - Rekomendacja: **A**.

### E. Introspekcja, CLI i serwer

21. **Gdzie działa serwer :7777?**
    - A: tylko w konfiguracji Debug obu schematów i tylko na 127.0.0.1; wycięty z Release, TestFlight i App Store.
    - B: także w buildach Development dystrybuowanych przez TestFlight.
    - Rekomendacja: **A**.
22. **Jak modelujemy w CLI zdarzenia systemowe (Sign in with Apple, prompt MusicKit, OAuth Spotify)?**
    - A: jako akcje z danymi, np. `CompleteSignIn {userId}`, a wyniki systemowych okien skryptuje fixtura.
    - B: pomijamy te przepływy w podróżach i testujemy je tylko palcem.
    - Rekomendacja: **A**. To najbardziej wrażliwe przepływy, więc najbardziej potrzebują podróży.
23. **Czy w podróżach sprawdzamy analitykę?**
    - A: tak, przez węzeł `Analytics` dostępny tylko w CLI, dla zgody, oceny, logowania i wylogowania.
    - B: nie, analityka zostaje w testach jednostkowych.
    - Rekomendacja: **A**.

### F. Znaleziska poboczne

24. **Co robimy z nonce w `LoginPromptView`?**
    - Fakt: `request.nonce` i `requestedScopes` są ustawiane w `Task` po wyjściu z synchronicznego `onRequest` (`LoginPromptView.swift:107`). `SettingsView.swift:185` robi to poprawnie: nonce jest policzony, zanim pokaże się przycisk.
    - Hipoteza do sprawdzenia: żądanie może wyjść bez nonce i zakresów (spike B w fazie 0).
    - A: jeśli się potwierdzi, osobny mały PR przed migracją, wzorem Settings.
    - B: naprawa dopiero w migracji LoginPrompt (faza 5), gdzie nonce trafia do stanu.
    - Rekomendacja: **A**.

### Decyzje projektowe M1–M9 (przyjęte)

- **M1.** Korzeń nazywa się `BeatRateApp` (jak `InventoryApp`), a punkt wejścia SwiftUI zmienia nazwę na `BeatRateMain`.
- **M2.** Nowe miejsca: `Core/IntrospectionKit` (kopia z repo), `Presentation/AppRoot` (zastępuje `TabBar` oraz `AppView` i `AppDataModel`), `Domain/Composition` (`Edges`, `Graph`), `Tools/BeatRateCLI`, `behavior/` oraz skrypty `./cli` i `./test` w katalogu głównym.
- **M3.** `AlbumDetailsContainer` i `AlbumDetailsView` łączą się w jeden `AlbumDetailsViewModel` z fazą ładowania (źródło: album albo samo id).
- **M4.** Stan trzyma modele domenowe (`AlbumModel`, `HomeSection`) z dodanym `Encodable` zamiast osobnych modeli wierszy, więc `ls` będzie dłuższy.
- **M5.** Jedynym polem ViewModelu poza `State` może być uchwyt efektu (`Task`), a nieaktualne odpowiedzi odrzuca `update` po porównaniu ze stanem.
- **M6.** `FakeRealtimeDatabase` z testów FirebaseService przechodzi do współdzielonego targetu `FirebaseServiceFakes` i służy też CLI.
- **M7.** CLAUDE.md aktualizujemy już w fazie 1.
- **M8.** `StackView` ze strażnikiem 0,5 s kopiujemy z repo bez zmian.
- **M9.** `HomeSectionView` i `SectionAlbumsGridView` w CoreUI dostają zamknięcie `onSelect` zamiast `Binding<AlbumModel?>`.

### Arkusz decyzji

Stan arkusza po odpowiedziach z 24.11.2026; kolumna „Uwagi” pozostała pusta.

| # | Decyzja do podjęcia | Rekomendacja | Decyzja | Uwagi |
| --- | --- | --- | --- | --- |
| 1 | Strategia migracji | A: inkrementalnie | Akceptuję rekomendację |  |
| 2 | Kryteria bramki G2 | przyjąć; próg kosztu po fazie 0 | Akceptuję rekomendację |  |
| 3 | Dopuszczalne zmiany zachowania | B: 1:1 + nazwane wyjątki | Akceptuję rekomendację |  |
| 4 | Kolejność ekranów | A: główna podróż najpierw | Akceptuję rekomendację |  |
| 5 | Podział pakietów Presentation | A: dwa targety w pakiecie | Akceptuję rekomendację |  |
| 6 | `DataModel` → `ViewModel` | A: tak | Akceptuję rekomendację |  |
| 7 | Kod SDK | A: targety `…Live` | Akceptuję rekomendację |  |
| 8 | Graf zależności | A: composition root od fazy 1 | Akceptuję rekomendację |  |
| 9 | Protokół `ViewModel` | A: kopia `internal` | Akceptuję rekomendację |  |
| 10 | `screen_view` | A: z nawigacji | Akceptuję rekomendację |  |
| 11 | Ładowanie zakładek | B: przy pierwszym fokusie | Akceptuję rekomendację |  |
| 12 | Zmiany sesji w ekranach | A: rozsyłanie z korzenia | Akceptuję rekomendację |  |
| 13 | Teksty w stanie | A: enumy | Akceptuję rekomendację |  |
| 14 | Wyjątki od „wszystko w State” | tak, lista zamknięta | Akceptuję rekomendację |  |
| 15 | Flagi upcoming z repo | A: nie teraz | Akceptuję rekomendację |  |
| 16 | Runner podróży | A: Node + CLI | Akceptuję rekomendację |  |
| 17 | Polityka pokrycia | A, potem sprawdzić B | Akceptuję rekomendację |  |
| 18 | Format fixtur | tak | Akceptuję rekomendację |  |
| 19 | Stare testy DataModeli | A: kasować przy migracji | Akceptuję rekomendację |  |
| 20 | Podróże w Xcode Cloud | A: po fazie 4 | Akceptuję rekomendację |  |
| 21 | Serwer :7777 | A: tylko Debug | Akceptuję rekomendację |  |
| 22 | Zdarzenia systemowe w CLI | A: akcje + fixtury | Akceptuję rekomendację |  |
| 23 | Analityka w podróżach | A: tak | Akceptuję rekomendację |  |
| 24 | Nonce w `LoginPromptView` | A: osobny PR, jeśli potwierdzone | Akceptuję rekomendację |  |
| M1–M9 | Moje decyzje (w uwagach numery odrzucone) | akceptacja wszystkich | Akceptuję rekomendację |  |
