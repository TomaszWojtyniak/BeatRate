import FirebaseService
import Foundation
import HomeRepository
import Models
import MusicKitService
import MusicRepository
import SpotifyService

/// Main-actor classes because the protocols inherit their packages' default
/// main-actor isolation.
struct StubError: Error {}

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

/// `SetHomeUseCase` keeps a MusicKit service it never calls; this one only satisfies the init.
@MainActor
final class StubMusicKitService: MusicKitServiceProtocol {
    func requestMusicAuthorization() async -> MusicAuthorizationResult { MusicAuthorizationResult(status: .authorized, hasSubscription: true) }
    func isAuthorized() async -> Bool { true }
    func isAuthorizationDetermined() async -> Bool { true }
    func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData? { nil }
    func fetchArtistData(byId artistId: String) async throws -> AppleMusicArtistData? { nil }
    func fetchArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData? { nil }
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] { [] }
    func search(searchTerm: String) async throws -> MusicSearchResults { .empty }
    func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData] { [] }
}
