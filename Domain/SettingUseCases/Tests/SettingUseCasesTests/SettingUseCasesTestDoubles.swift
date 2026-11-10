import AuthenticationServices
import CoreApp
import Foundation
import LoginUseCases
import Models
import MusicRepository
import SpotifyService

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

    func performCompleteLogin(authResult: ASAuthorization) async throws -> String { "" }

    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        if failsToSaveProfile { throw StubError() }
        savedProfiles.append((userId, profile))
        profiles[userId] = profile
    }
}

/// Player state over a throwaway defaults suite, so tests never touch `.standard`.
@MainActor
func makePlayerManager() -> (MusicPlayerManager, UserDefaultsManager) {
    let defaults = UserDefaultsManager(defaults: UserDefaults(suiteName: "SettingUseCasesTests.\(UUID())")!)
    return (MusicPlayerManager(userDefaultsManager: defaults), defaults)
}
