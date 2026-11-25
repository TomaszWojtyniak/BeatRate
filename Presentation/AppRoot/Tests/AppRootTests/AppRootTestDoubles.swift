import Analytics
import AppUseCases
import AuthenticationServices
import Composition
import CoreApp
import FirebaseService
import Foundation
import Models
import MusicKitService
import Security
import Splash
import SplashUseCases
import SpotifyService
import SwiftDataManager
import Synchronization
@testable import AppRoot

struct StubError: Error {}

func temporaryDefaults() -> UserDefaults {
    UserDefaults(suiteName: FileManager.default.temporaryDirectory.appending(path: "AppRootTests.\(UUID())").path)!
}

/// Records analytics calls instead of sending them.
final class StubAnalyticsBackend: AnalyticsBackend {
    private(set) var events: [String] = []
    private(set) var userIDs: [String?] = []

    func logEvent(_ name: String, parameters: [String: Any]?) { events.append(name) }
    func setUserID(_ userId: String?) { userIDs.append(userId) }
    func setConsent(analyticsGranted: Bool) {}
    func setCollectionEnabled(_ enabled: Bool) {}
    func resetData() {}
    func setUserProperty(_ value: String?, forName name: String) {}
}

/// Records the user identifiers crash reports are tagged with.
nonisolated final class StubCrashBackend: CrashBackend {
    private let ids = Mutex<[String?]>([])
    var userIDs: [String?] { ids.withLock { $0 } }

    func setUserID(_ userId: String?) { ids.withLock { $0.append(userId) } }
    func setCollectionEnabled(_ enabled: Bool) {}
    func record(_ error: Error) {}
    func log(_ message: String) {}
    func setCustomValue(_ value: String, forKey key: String) {}
}

/// The login state as the store reports it; `login` and `logout` push to the one stream.
final class StubAppUseCase: GetAppUseCaseProtocol {
    var isLoggedIn = false
    var user: User?
    var failsToLoadUser = false
    private let stream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
    }

    func getCurrentUser() async throws -> User? {
        if failsToLoadUser { throw StubError() }
        return user
    }
    func isUserLoggedIn() async -> Bool { isLoggedIn }
    func observeLoginState() -> AsyncStream<Bool> { stream }
    func push(_ isLoggedIn: Bool) { continuation.yield(isLoggedIn) }
}

/// A splash that never gets past its first step, so a test finishes it by hand.
final class StalledSplash: GetSplashUseCaseProtocol {
    func isUserLoggedIn() async -> Bool {
        try? await Task.sleep(for: .seconds(3600))
        return false
    }
    func getCachedSections() async throws -> [HomeSection] { [] }
    func fetchHomeSections() async throws -> [HomeSection] { [] }
    func authorizeMusicKit() async -> Bool { true }
    func isMusicKitAuthorizationDetermined() async -> Bool { true }
    func hydrateMainMusicPlayer() async -> Bool { true }
    func verifySpotifyConnection() async -> SpotifyConnectionState { .notConnected }
    func refreshSpotifyPremium(_ premium: SpotifyPremiumStatus) async {}
    func cacheSections(_ sections: [HomeSection]) async throws {}
    func isCacheValid() async -> Bool { false }
    func areCredentialsValid() async -> Bool { true }
    func logout() async throws {}
    func getCurrentNonce() async -> String { "" }
    func deleteAccount(credential: AppleSignInCredential) async throws {}
}

/// Everything an `AppNavigator` talks to, as doubles, and the splashes it has made.
final class Harness {
    let app = StubAppUseCase()
    let session = SessionManager()
    let players = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: temporaryDefaults()))
    let backend = StubAnalyticsBackend()
    let crash = StubCrashBackend()
    let analytics: AnalyticsManager
    private(set) var splashes: [SplashViewModel] = []
    private var finishers: [() -> Void] = []

    init(consent: Bool? = nil) {
        analytics = AnalyticsManager(defaults: temporaryDefaults(), backend: backend)
        if let consent { analytics.setConsent(consent) }
    }

    func navigator() -> AppNavigator {
        AppNavigator(getApp: app, session: session, players: players, analytics: analytics,
                     crashLogger: CrashLogger(backend: crash)) { onFinish in
            let splash = SplashViewModel(getSplash: StalledSplash(), players: self.players, analytics: self.analytics,
                                         retryDelay: .zero, onFinish: onFinish)
            self.splashes.append(splash)
            self.finishers.append(onFinish)
            return splash
        }
    }

    /// Ends the latest splash the way it ends itself.
    func finishSplash() { finishers.last?() }
}

/// Waits up to a second for `condition`, for effects that run on their own tasks.
func eventually(_ condition: () -> Bool) async {
    for _ in 0..<200 where !condition() {
        try? await Task.sleep(for: .milliseconds(5))
    }
}

extension Edges {
    /// Every edge stubbed: nobody signed in, nothing stored, nothing reachable.
    static func stub() -> Edges {
        Edges(
            database: EmptyDatabase(),
            firebaseAuth: SignedOutAuth(),
            musicKit: DeniedMusicKit(),
            spotifyTransport: OfflineTransport(),
            spotifyPresenter: { nil },
            keychain: EmptyKeychain(),
            appleIDCredentialState: { _ in .notFound },
            defaults: temporaryDefaults(),
            modelContainer: SwiftDataManager.inMemoryContainer(),
            analytics: StubAnalyticsBackend(),
            crash: StubCrashBackend(),
            retryDelay: .zero
        )
    }
}

struct EmptyDatabase: RealtimeDatabase {
    func read(_ path: String) async throws -> DatabaseValue { DatabaseValue(nil) }
    func write(_ value: DatabaseValue, to path: String) async throws {}
    func update(_ path: String, with values: [String: DatabaseValue]) async throws {}
    func serverTimestamp() -> DatabaseValue { DatabaseValue(nil) }
}

struct SignedOutAuth: FirebaseAuthProviding {
    func currentUserId() async -> String? { nil }
    func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> FirebaseSignIn { throw StubError() }
    func signOut() async throws {}
    func reauthenticate(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws { throw StubError() }
    func revokeToken(authorizationCode: String) async throws {}
    func deleteCurrentUser() async throws { throw StubError() }
}

struct DeniedMusicKit: MusicKitServiceProtocol {
    func requestMusicAuthorization() async -> MusicAuthorizationResult {
        await MusicAuthorizationResult(status: .denied, hasSubscription: false)
    }
    func isAuthorized() async -> Bool { false }
    func isAuthorizationDetermined() async -> Bool { true }
    func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData? { nil }
    func fetchArtistData(byId artistId: String) async throws -> AppleMusicArtistData? { nil }
    func fetchArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData? { nil }
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] { [] }
    func search(searchTerm: String) async throws -> MusicSearchResults { throw StubError() }
    func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData] { [] }
}

struct OfflineTransport: SpotifyTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw StubError() }
}

struct EmptyKeychain: KeychainBackend {
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus { errSecItemNotFound }
    func add(_ attributes: [String: Any]) -> OSStatus { errSecSuccess }
    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) { (errSecItemNotFound, nil) }
    func delete(_ query: [String: Any]) -> OSStatus { errSecSuccess }
}
