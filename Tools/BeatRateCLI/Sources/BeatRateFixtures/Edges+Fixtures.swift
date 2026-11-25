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
        if let appleUserID = try fixtures.string("device/keychain/appleUserID") {
            try await KeychainManager(backend: keychain).saveAppleUserID(appleUserID)
        }
        let container = SwiftDataManager.inMemoryContainer()
        if let userId = try fixtures.string("device/loggedInUserId") {
            try await SwiftDataManager(container: container, appleUserIDStore: KeychainManager(backend: keychain))
                .setUserLoggedIn(userId: userId)
        }
        // Named by a path in the temporary directory: a plain name would leave a plist in ~/Library/Preferences.
        let defaults = UserDefaults(suiteName: FileManager.default.temporaryDirectory.appending(path: "BeatRateCLI.\(UUID())").path)!
        for (key, value) in try fixtures.object("device/defaults") ?? [:] {
            defaults.set(value, forKey: key)
        }
        let credentialState = try fixtures.choice("device/appleIDState", appleIDStates) ?? .notFound

        return Edges(
            database: FakeRealtimeDatabase(
                DatabaseValue(fixtures.value(at: "db")),
                failingReads: Set(try fixtures.strings("dbFailures/reads") ?? []),
                failingWrites: Set(try fixtures.strings("dbFailures/writes") ?? []),
                delay: .milliseconds(try fixtures.int("dbDelayMs") ?? 0)
            ),
            firebaseAuth: FakeFirebaseAuth(userId: try fixtures.string("device/firebaseUid")),
            musicKit: FakeMusicKitService(
                status: try fixtures.choice("music/authorization", musicAccess) ?? .authorized,
                answer: try fixtures.choice("music/answer", musicAccess) ?? .authorized,
                hasSubscription: try fixtures.bool("music/subscription") ?? false,
                albums: try albums(try fixtures.object("music/albums") ?? [:])
            ),
            spotifyTransport: FakeSpotifyTransport(),
            spotifyPresenter: { nil },
            keychain: keychain,
            appleIDCredentialState: { _ in credentialState },
            defaults: defaults,
            modelContainer: container,
            analytics: FakeAnalyticsBackend(),
            crash: NoCrashBackend(),
            retryDelay: .milliseconds(try fixtures.int("timing/retryDelayMs") ?? 0)
        )
    }
}

private let musicAccess: [String: MusicAccessStatus] = [
    "notDetermined": .notDetermined, "denied": .denied, "restricted": .restricted, "authorized": .authorized,
]

private let appleIDStates: [String: ASAuthorizationAppleIDProvider.CredentialState] = [
    "authorized": .authorized, "revoked": .revoked, "notFound": .notFound, "transferred": .transferred,
]

private func albums(_ json: [String: Any]) throws -> [String: AppleMusicAlbumData] {
    try json.mapValues { try JSONDecoder().decode(AppleMusicAlbumData.self, from: JSONSerialization.data(withJSONObject: $0)) }
}
