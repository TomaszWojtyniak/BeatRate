import Foundation
import Models
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
