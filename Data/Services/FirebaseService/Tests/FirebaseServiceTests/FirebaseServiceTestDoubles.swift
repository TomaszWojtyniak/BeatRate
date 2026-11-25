import Analytics
import CoreApp
import FirebaseServiceFakes
import Foundation
import Models
import Security
@testable import FirebaseService

struct StubError: Error {}

/// Records every analytics event instead of sending it to Firebase.
final class StubAnalyticsBackend: AnalyticsBackend {
    private(set) var events: [(name: String, parameters: [String: Any]?)] = []

    func setConsent(analyticsGranted: Bool) {}
    func setCollectionEnabled(_ enabled: Bool) {}
    func resetData() {}
    func setUserProperty(_ value: String?, forName name: String) {}
    func logEvent(_ name: String, parameters: [String: Any]?) { events.append((name, parameters)) }
    func setUserID(_ userId: String?) {}
}

@MainActor
func makeAnalytics(_ backend: StubAnalyticsBackend = StubAnalyticsBackend()) -> AnalyticsManager {
    AnalyticsManager(defaults: UserDefaults(suiteName: FileManager.default.temporaryDirectory.appending(path: "FirebaseServiceTests.\(UUID())").path)!, backend: backend)
}

/// Scripted Firebase Auth: canned sign-in result and signed-in user; records what the service asks of it.
actor StubFirebaseAuth: FirebaseAuthProviding {
    private let signInResult: FirebaseSignIn
    private let currentUser: String?
    private let revokeError: (any Error)?
    private let signOutError: (any Error)?
    private(set) var signOutCount = 0
    private(set) var deleteCount = 0
    private(set) var revokedCodes: [String] = []
    private(set) var reauthenticatedTokens: [String] = []

    init(signInResult: FirebaseSignIn = .init(userId: "u1", email: nil, isNewUser: false), currentUser: String? = "u1",
         revokeError: (any Error)? = nil, signOutError: (any Error)? = nil) {
        self.signInResult = signInResult
        self.currentUser = currentUser
        self.revokeError = revokeError
        self.signOutError = signOutError
    }

    func currentUserId() -> String? { currentUser }
    func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) -> FirebaseSignIn { signInResult }

    func signOut() throws {
        signOutCount += 1
        if let signOutError { throw signOutError }
    }

    func reauthenticate(idToken: String, rawNonce: String, fullName: PersonNameComponents?) {
        reauthenticatedTokens.append(idToken)
    }

    func revokeToken(authorizationCode: String) throws {
        revokedCodes.append(authorizationCode)
        if let revokeError { throw revokeError }
    }

    func deleteCurrentUser() { deleteCount += 1 }
}

/// Keychain that stores nothing; with `failing`, every write and delete fails with `errSecIO`.
struct StubKeychainBackend: KeychainBackend {
    let failing: Bool

    private var status: OSStatus { failing ? errSecIO : errSecSuccess }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus { status }
    func add(_ attributes: [String: Any]) -> OSStatus { status }
    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) { (errSecItemNotFound, nil) }
    func delete(_ query: [String: Any]) -> OSStatus { status }
}

/// Canned profile lookup; records every profile the service tries to save.
/// A main-actor class because the protocol inherits the package's main-actor isolation.
@MainActor
final class StubDatabaseFirebaseService: DatabaseFirebaseServiceProtocol {
    private let existingProfile: FirebaseUserProfile?
    private let failsToRead: Bool
    private let failsToSave: Bool
    private(set) var savedProfiles: [(userId: String, profile: FirebaseUserProfile)] = []

    init(existingProfile: FirebaseUserProfile? = nil, failsToRead: Bool = false, failsToSave: Bool = false) {
        self.existingProfile = existingProfile
        self.failsToRead = failsToRead
        self.failsToSave = failsToSave
    }

    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? {
        if failsToRead { throw StubError() }
        return existingProfile
    }

    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        if failsToSave { throw StubError() }
        savedProfiles.append((userId, profile))
    }

    func fetchSections() async throws -> [FirebaseAlbumSection] { [] }
    func fetchAlbumData(albumId: String) async throws -> FirebaseAlbumData? { nil }
    func getUserRating(userId: String, albumId: String) async throws -> Double? { nil }
    func getUserRatedAlbumIds(userId: String) async throws -> [String] { [] }
    func getAllUserRatings(userId: String) async throws -> [String: Double] { [:] }
    func getUserRatingsSorted(userId: String) async throws -> [(albumId: String, rating: Double)] { [] }
    func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws -> (avgRating: Double, ratingCount: Int) { (0, 0) }
    func removeUserRating(userId: String, albumId: String) async throws -> (avgRating: Double, ratingCount: Int) { (0, 0) }
    func getFavoriteAlbumIds(userId: String) async throws -> [String] { [] }
    func saveFavoriteAlbumIds(userId: String, albumIds: [String]) async throws {}
    func deleteUserData(userId: String) async throws {}
}

@MainActor
func makeDatabaseService(_ database: FakeRealtimeDatabase, now: Date = Date(timeIntervalSince1970: 1_000)) -> DatabaseFirebaseService {
    DatabaseFirebaseService(crashLogger: .shared, database: database, now: { now })
}
