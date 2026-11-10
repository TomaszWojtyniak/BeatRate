import AuthenticationServices
import FirebaseService
import Foundation
import Models

struct StubError: Error {}

/// Main-actor classes because the service protocols inherit their package's
/// default main-actor isolation.
@MainActor
final class StubAuthFirebaseService: AuthFirebaseServiceProtocol {
    var userId: String?
    var signOutError: StubError?
    private(set) var signOutCount = 0

    func currentUserId() async -> String? { userId }

    func signOut() async throws {
        signOutCount += 1
        if let signOutError { throw signOutError }
    }

    func setLoginData(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws -> String { "" }
    func reauthenticate(idTokenString: String, nonce: String, appleIDCredential: ASAuthorizationAppleIDCredential) async throws {}
    func revokeAndDeleteUser(authorizationCode: String?) async throws {}
}

@MainActor
final class StubDatabaseFirebaseService: DatabaseFirebaseServiceProtocol {
    var profiles: [String: FirebaseUserProfile] = [:]
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
    func deleteUserData(userId: String) async throws {}
}
