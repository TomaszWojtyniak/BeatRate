import AuthenticationServices
import Foundation
import LoginRepository
import Models
import SwiftData
import SwiftDataManager

struct StubError: Error {}

/// Main-actor classes because the protocols inherit their packages' default
/// main-actor isolation.
@MainActor
final class StubLoginRepository: LoginRepositoryProtocol {
    var firebaseUserId: String?
    var nonce = "nonce"
    var profiles: [String: FirebaseUserProfile] = [:]
    var failsToReadProfile = false
    var failsToSaveProfile = false
    var failsToSignOut = false
    private(set) var savedProfiles: [(userId: String, profile: FirebaseUserProfile)] = []
    private(set) var signOutCount = 0

    func currentFirebaseUserId() async -> String? { firebaseUserId }
    func setLoginData(authResult: ASAuthorization) async throws -> String { "" }
    func getCurrentNonce() async -> String { nonce }

    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? {
        if failsToReadProfile { throw StubError() }
        return profiles[userId]
    }

    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        if failsToSaveProfile { throw StubError() }
        savedProfiles.append((userId, profile))
    }

    func signOut() async throws {
        signOutCount += 1
        if failsToSignOut { throw StubError() }
    }

    func deleteAccount(userId: String, authResult: ASAuthorization) async throws {}
}

/// Scriptable stand-in for the SwiftData cache, for failure paths an in-memory
/// `SwiftDataManager` cannot produce.
@MainActor
final class StubSwiftDataManager: SwiftDataManagerProtocol {
    var userId: String?
    var loggedIn = false
    var failsToReadUserId = false
    var failsToLogIn = false
    var failsToLogOut = false
    private(set) var loggedInUserIds: [String] = []
    private(set) var logOutCount = 0
    private let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    var context: ModelContext { container.mainContext }

    func getCurrentUserId() async throws -> String? {
        if failsToReadUserId { throw StubError() }
        return userId
    }

    func setUserLoggedIn(userId: String) async throws {
        if failsToLogIn { throw StubError() }
        loggedInUserIds.append(userId)
        self.userId = userId
        loggedIn = true
    }

    func setUserLoggedOut() async throws {
        logOutCount += 1
        if failsToLogOut { throw StubError() }
        loggedIn = false
    }

    func isUserLoggedIn() async -> Bool { loggedIn }

    func cacheAlbum(id: String, album: AlbumModel) async throws {}
    func cacheSections(_ sections: [HomeSection]) async throws {}
    func getCachedSections() async throws -> [HomeSection] { [] }
    func getCachedAlbum(id: String) async throws -> AlbumModel? { nil }
    func updateCachedAlbum(albumId: String, firebaseData: FirebaseAlbumData) async throws {}
    func getCachedUserRating(albumId: String) async throws -> Double? { nil }
    func cacheUserRating(albumId: String, rating: Double) async throws {}
    func removeCachedUserRating(albumId: String) async throws {}
    func cacheUserRatings(_ ratings: [String: Double]) async throws {}
    func clearCache() async throws {}
    func clearAllCacheForLogout() async throws {}
    func isCacheValid() async -> Bool { false }
    func getCurrentUser() async throws -> User? { nil }
    func observeLoginState() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func getRecentAlbums() async throws -> [AppleMusicAlbumData] { [] }
    func saveRecentAlbum(_ album: AppleMusicAlbumData) async throws {}
    func clearRecentAlbums() async throws {}
}
