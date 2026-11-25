import Analytics
import AuthenticationServices
import Composition
import CoreApp
import FirebaseService
import FirebaseServiceFakes
import Foundation
import Models
import MusicKitService
import SwiftDataManager

public extension Edges {
    /// The edges a headless session runs on, built from its fixture files.
    ///
    /// | Fixture | Edge |
    /// | --- | --- |
    /// | `db`, `dbFailures.reads/writes`, `dbDelayMs` | `FakeRealtimeDatabase` |
    /// | `music.authorization/answer/subscription/albums` | `FakeMusicKitService` |
    /// | `device.firebaseUid` | `FakeFirebaseAuth` |
    /// | `device.keychain.appleUserID` | `FakeKeychainBackend` |
    /// | `device.appleIDState` | Apple ID credential state |
    /// | `device.loggedInUserId` | the login row in an in-memory SwiftData store |
    /// | `device.defaults` | a fresh `UserDefaults` suite |
    /// | `timing.retryDelayMs` | `retryDelay` |
    static func fixtures(_ fixtures: Fixtures) async throws -> Edges {
        let keychain = FakeKeychainBackend()
        if let appleUserID = fixtures.value(at: "device/keychain/appleUserID") as? String {
            try await KeychainManager(backend: keychain).saveAppleUserID(appleUserID)
        }
        let container = SwiftDataManager.inMemoryContainer()
        if let userId = fixtures.value(at: "device/loggedInUserId") as? String {
            try await SwiftDataManager(container: container, appleUserIDStore: KeychainManager(backend: keychain))
                .setUserLoggedIn(userId: userId)
        }
        // Named by a path in the temporary directory: a plain name would leave a plist in ~/Library/Preferences.
        let defaults = UserDefaults(suiteName: FileManager.default.temporaryDirectory.appending(path: "BeatRateCLI.\(UUID())").path)!
        for (key, value) in fixtures.value(at: "device/defaults") as? [String: Any] ?? [:] {
            defaults.set(value, forKey: key)
        }
        let credentialState = appleIDState(fixtures.value(at: "device/appleIDState") as? String)

        return Edges(
            database: FakeRealtimeDatabase(
                DatabaseValue(fixtures.value(at: "db")),
                failingReads: Set(fixtures.value(at: "dbFailures/reads") as? [String] ?? []),
                failingWrites: Set(fixtures.value(at: "dbFailures/writes") as? [String] ?? []),
                delay: .milliseconds(fixtures.value(at: "dbDelayMs") as? Int ?? 0)
            ),
            firebaseAuth: FakeFirebaseAuth(userId: fixtures.value(at: "device/firebaseUid") as? String),
            musicKit: FakeMusicKitService(
                status: musicAccess(fixtures.value(at: "music/authorization") as? String),
                answer: musicAccess(fixtures.value(at: "music/answer") as? String),
                hasSubscription: fixtures.value(at: "music/subscription") as? Bool ?? false,
                albums: try albums(fixtures.value(at: "music/albums") as? [String: Any] ?? [:])
            ),
            spotifyTransport: FakeSpotifyTransport(),
            spotifyPresenter: { nil },
            keychain: keychain,
            appleIDCredentialState: { _ in credentialState },
            defaults: defaults,
            modelContainer: container,
            analytics: FakeAnalyticsBackend(),
            crash: NoCrashBackend(),
            retryDelay: .milliseconds(fixtures.value(at: "timing/retryDelayMs") as? Int ?? 0)
        )
    }
}

private func musicAccess(_ name: String?) -> MusicAccessStatus {
    switch name {
    case "notDetermined": .notDetermined
    case "denied": .denied
    case "restricted": .restricted
    default: .authorized
    }
}

private func appleIDState(_ name: String?) -> ASAuthorizationAppleIDProvider.CredentialState {
    switch name {
    case "authorized": .authorized
    case "revoked": .revoked
    case "transferred": .transferred
    default: .notFound
    }
}

private func albums(_ json: [String: Any]) throws -> [String: AppleMusicAlbumData] {
    try json.mapValues { try JSONDecoder().decode(AppleMusicAlbumData.self, from: JSONSerialization.data(withJSONObject: $0)) }
}
