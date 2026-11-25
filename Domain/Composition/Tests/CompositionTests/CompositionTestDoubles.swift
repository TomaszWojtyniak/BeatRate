import Analytics
import AuthenticationServices
import Composition
import CoreApp
import FirebaseService
import Foundation
import Models
import MusicKitService
import Security
import SpotifyService
import SwiftDataManager

struct StubError: Error {}

/// Records every analytics event instead of sending it.
final class StubAnalyticsBackend: AnalyticsBackend {
    private(set) var events: [(name: String, parameters: [String: Any]?)] = []

    func setConsent(analyticsGranted: Bool) {}
    func setCollectionEnabled(_ enabled: Bool) {}
    func resetData() {}
    func setUserProperty(_ value: String?, forName name: String) {}
    func logEvent(_ name: String, parameters: [String: Any]?) { events.append((name, parameters)) }
    func setUserID(_ userId: String?) {}
}

/// A database with no nodes that accepts and forgets every write.
struct EmptyDatabase: RealtimeDatabase {
    func read(_ path: String) async throws -> DatabaseValue { DatabaseValue(nil) }
    func write(_ value: DatabaseValue, to path: String) async throws {}
    func update(_ path: String, with values: [String: DatabaseValue]) async throws {}
    func serverTimestamp() -> DatabaseValue { DatabaseValue(nil) }
}

/// Firebase Auth with nobody signed in and every sign-in refused.
struct SignedOutAuth: FirebaseAuthProviding {
    func currentUserId() async -> String? { nil }
    func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> FirebaseSignIn { throw StubError() }
    func signOut() async throws {}
    func reauthenticate(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws { throw StubError() }
    func revokeToken(authorizationCode: String) async throws {}
    func deleteCurrentUser() async throws { throw StubError() }
}

/// MusicKit with access denied and an empty catalog.
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

/// Spotify's API with the network down.
struct OfflineTransport: SpotifyTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw StubError() }
}

/// A keychain that holds nothing and accepts every write.
struct EmptyKeychain: KeychainBackend {
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus { errSecItemNotFound }
    func add(_ attributes: [String: Any]) -> OSStatus { errSecSuccess }
    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) { (errSecItemNotFound, nil) }
    func delete(_ query: [String: Any]) -> OSStatus { errSecSuccess }
}

struct NoCrashReports: CrashBackend {
    func setCollectionEnabled(_ enabled: Bool) {}
    func setUserID(_ userId: String?) {}
    func record(_ error: Error) {}
    func log(_ message: String) {}
    func setCustomValue(_ value: String, forKey key: String) {}
}

extension Edges {
    /// Every edge stubbed: nobody signed in, nothing stored, nothing reachable.
    @MainActor
    static func stub(
        defaults: UserDefaults = UserDefaults(suiteName: "Graph.\(UUID())")!,
        analytics: any AnalyticsBackend = StubAnalyticsBackend()
    ) -> Edges {
        Edges(
            database: EmptyDatabase(),
            firebaseAuth: SignedOutAuth(),
            musicKit: DeniedMusicKit(),
            spotifyTransport: OfflineTransport(),
            spotifyPresenter: { nil },
            keychain: EmptyKeychain(),
            appleIDCredentialState: { _ in .notFound },
            defaults: defaults,
            modelContainer: SwiftDataManager.inMemory().container,
            analytics: analytics,
            crash: NoCrashReports()
        )
    }
}
