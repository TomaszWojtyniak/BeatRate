import AuthenticationServices
import FirebaseService
import CoreApp
import FirebaseService
import Foundation
import HomeRepository
import LoginRepository
import LoginUseCases
import Models
import MusicRepository
import SpotifyService
import SwiftData
import SwiftDataManager
import Synchronization
@testable import SplashUseCases

struct StubError: Error {}

/// Main-actor classes because the protocols inherit their packages' default
/// main-actor isolation.
@MainActor
final class StubMusicRepository: MusicRepositoryProtocol {
    var authorization = MusicAuthorizationInfo(isAuthorized: true, hasSubscription: true)
    var spotifyAuthorization: Result<SpotifyAuthorizationInfo, StubError> = .success(SpotifyAuthorizationInfo(isAuthorized: true, premium: .premium))
    var album: Result<AppleMusicAlbumData, StubError> = .failure(StubError())
    var artist: Result<AppleMusicArtistData, StubError> = .failure(StubError())
    var searchResults = MusicSearchResults.empty
    var appleMusicAuthorized = true
    var authorizationDetermined = true
    var storedSpotifySession = true
    var spotifyConnection = SpotifyConnectionState.connected(premium: .premium)
    private(set) var searchedTerms: [String] = []
    private(set) var artistLookups: [String] = []

    func requestMusicAuthorization() async -> MusicAuthorizationInfo { authorization }
    func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo { try spotifyAuthorization.get() }
    func fetchRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AppleMusicAlbumData] { [] }
    func hasStoredSpotifySession() async -> Bool { storedSpotifySession }
    func verifySpotifyConnection() async -> SpotifyConnectionState { spotifyConnection }
    func isAppleMusicAuthorized() async -> Bool { appleMusicAuthorized }
    func isMusicKitAuthorizationDetermined() async -> Bool { authorizationDetermined }
    func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData { try album.get() }

    func getArtistData(byId artistId: String) async throws -> AppleMusicArtistData {
        artistLookups.append("id:\(artistId)")
        return try artist.get()
    }

    func getArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData {
        artistLookups.append("album:\(albumId)")
        return try artist.get()
    }

    func search(searchTerm: String) async throws -> MusicSearchResults {
        searchedTerms.append(searchTerm)
        return searchResults
    }
}

@MainActor
final class StubHomeRepository: HomeRepositoryProtocol {
    var sections: [HomeSection] = []
    var cachedAlbum: AlbumModel?
    var fetchedAlbum: Result<AlbumModel, StubError> = .failure(StubError())
    var firebaseAlbum: Result<FirebaseAlbumData?, StubError> = .success(nil)
    var userRating: Double?
    private(set) var savedRatings: [(albumId: String, rating: Double, title: String?)] = []
    private(set) var invalidateCount = 0

    func fetchHomeSections() async throws -> [HomeSection] { sections }
    func getUserRating(albumId: String) async throws -> Double? { userRating }

    func saveAlbumRating(albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws {
        savedRatings.append((albumId, rating, albumMetadata?.title))
    }

    func getCachedAlbum(albumId: String) async throws -> AlbumModel? { cachedAlbum }
    func fetchAndCacheAlbum(albumId: String) async throws -> AlbumModel { try fetchedAlbum.get() }
    func getFirebaseAlbumData(albumId: String) async throws -> FirebaseAlbumData? { try firebaseAlbum.get() }
    func invalidateUserCache() async { invalidateCount += 1 }
}

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
    var loginResult: Result<String, StubError> = .success("u")
    var failsToDeleteAccount = false
    private(set) var deletedAccounts: [String] = []

    func setLoginData(credential: AppleSignInCredential) async throws -> String { try loginResult.get() }
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

    func deleteAccount(userId: String, credential: AppleSignInCredential) async throws {
        if failsToDeleteAccount { throw StubError() }
        deletedAccounts.append(userId)
    }
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

/// One stub for both login use-case protocols: settings reads the profile
/// through one and writes it through the other.
@MainActor
final class StubLoginUseCases: GetLoginUseCaseProtocol, SetLoginUseCaseProtocol {
    var profiles: [String: FirebaseUserProfile] = [:]
    var failsToReadProfile = false
    var failsToSaveProfile = false
    private(set) var savedProfiles: [(userId: String, profile: FirebaseUserProfile)] = []

    func getCurrentNonce() async -> String { "nonce" }

    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? {
        if failsToReadProfile { throw StubError() }
        return profiles[userId]
    }

    func performCompleteLogin(credential: AppleSignInCredential) async throws -> String { "" }

    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        if failsToSaveProfile { throw StubError() }
        savedProfiles.append((userId, profile))
        profiles[userId] = profile
    }
}

/// A locked class rather than an actor: constructing an actor stub inside a
/// main-actor default argument trips a Swift 6.4 compiler bug.
final class StubAppleCredentialStore: AppleCredentialStore {
    private struct State {
        var appleUserID: String?
        var deletedAppleID = false
        var deletedSpotifyTokens = false
    }

    private let state: Mutex<State>
    private let failsToLoad: Bool

    init(appleUserID: String? = nil, failsToLoad: Bool = false) {
        state = Mutex(State(appleUserID: appleUserID))
        self.failsToLoad = failsToLoad
    }

    var deletedAppleID: Bool { state.withLock { $0.deletedAppleID } }
    var deletedSpotifyTokens: Bool { state.withLock { $0.deletedSpotifyTokens } }

    func loadAppleUserID() async throws -> String? {
        if failsToLoad { throw StubError() }
        return state.withLock { $0.appleUserID }
    }

    func deleteAppleUserID() async throws {
        state.withLock { $0.deletedAppleID = true }
    }

    func deleteSpotifyTokens() async throws {
        state.withLock { $0.deletedSpotifyTokens = true }
    }
}

extension AppleSignInCredential {
    static let fixture = AppleSignInCredential(user: "apple", identityToken: Data("token".utf8), authorizationCode: nil, email: nil, fullName: nil)
}
