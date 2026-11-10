import AuthenticationServices
import FirebaseService
import Foundation
import Models

struct StubError: Error {}

/// Shared by both stubs so a test can check the order of calls across them.
@MainActor
final class CallLog {
    private(set) var calls: [String] = []

    func record(_ call: String) { calls.append(call) }
}

enum Fixture {
    static func credential(token: Data? = Data("token".utf8), code: Data? = Data("code".utf8)) -> AppleSignInCredential {
        AppleSignInCredential(
            user: "apple-user", identityToken: token, authorizationCode: code,
            email: "a@b.c", fullName: PersonNameComponents(givenName: "Ann", familyName: "Lee")
        )
    }
}

/// Main-actor classes because the service protocols inherit their package's
/// default main-actor isolation.
@MainActor
final class StubAuthFirebaseService: AuthFirebaseServiceProtocol {
    var userId: String?
    var signOutError: StubError?
    private(set) var signOutCount = 0
    private(set) var signIns: [(idToken: String, nonce: String, appleUser: String)] = []
    private(set) var reauthentications: [(idToken: String, nonce: String, givenName: String?)] = []
    private(set) var revokedCodes: [String?] = []
    private let log: CallLog

    init(log: CallLog = CallLog()) {
        self.log = log
    }

    func currentUserId() async -> String? { userId }

    func signOut() async throws {
        signOutCount += 1
        if let signOutError { throw signOutError }
    }

    func setLoginData(idTokenString: String, nonce: String, credential: AppleSignInCredential) async throws -> String {
        signIns.append((idTokenString, nonce, credential.user))
        return "firebase-uid"
    }

    func reauthenticate(idTokenString: String, nonce: String, fullName: PersonNameComponents?) async throws {
        log.record("reauthenticate")
        reauthentications.append((idTokenString, nonce, fullName?.givenName))
    }

    func revokeAndDeleteUser(authorizationCode: String?) async throws {
        log.record("revokeAndDelete")
        revokedCodes.append(authorizationCode)
    }
}

@MainActor
final class StubDatabaseFirebaseService: DatabaseFirebaseServiceProtocol {
    var profiles: [String: FirebaseUserProfile] = [:]
    var failsToDeleteData = false
    private let log: CallLog

    init(log: CallLog = CallLog()) {
        self.log = log
    }
    private(set) var savedProfiles: [String: FirebaseUserProfile] = [:]

    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? { profiles[userId] }

    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        savedProfiles[userId] = profile
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
    func deleteUserData(userId: String) async throws {
        log.record("deleteUserData:\(userId)")
        if failsToDeleteData { throw StubError() }
    }
}
