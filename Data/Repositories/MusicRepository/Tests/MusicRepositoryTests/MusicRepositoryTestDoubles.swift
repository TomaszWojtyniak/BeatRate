import Foundation
import Models
import MusicKitService
import SpotifyService

struct StubError: Error {}

/// Main-actor classes because the service protocols inherit their packages'
/// default main-actor isolation. MusicKitServiceProtocol is the exception — it is
/// nonisolated so the Live actor can conform — so its witnesses say @MainActor
/// themselves, or Swift would infer them nonisolated.
@MainActor
final class StubMusicKitService: MusicKitServiceProtocol {
    var authorizationStatus: MusicAccessStatus = .authorized
    var hasSubscription = true
    var albums: [String: AppleMusicAlbumData] = [:]
    var artist: AppleMusicArtistData?
    var searchResults = MusicSearchResults.empty
    var catalogMatches: [String: [AppleMusicAlbumData]] = [:]
    var failingSearchTerms: Set<String> = []
    var recentlyPlayed: Result<[AppleMusicAlbumData], StubError> = .success([])
    var authorized = true
    var determined = true
    private(set) var authorizationRequests = 0
    private(set) var searchedTerms: [String] = []

    @MainActor func requestMusicAuthorization() async -> MusicAuthorizationResult {
        authorizationRequests += 1
        return MusicAuthorizationResult(status: authorizationStatus, hasSubscription: hasSubscription)
    }

    @MainActor func isAuthorized() async -> Bool { authorized }
    @MainActor func isAuthorizationDetermined() async -> Bool { determined }
    @MainActor func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData? { albums[id] }
    @MainActor func fetchArtistData(byId artistId: String) async throws -> AppleMusicArtistData? { artist }
    @MainActor func fetchArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData? { artist }
    @MainActor func search(searchTerm: String) async throws -> MusicSearchResults { searchResults }

    @MainActor func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] {
        searchedTerms.append(searchTerm)
        if failingSearchTerms.contains(searchTerm) { throw StubError() }
        return catalogMatches[searchTerm] ?? []
    }

    @MainActor func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData] {
        try recentlyPlayed.get()
    }
}

@MainActor
final class StubSpotifyService: SpotifyServiceProtocol {
    var authResult = SpotifyAuthResult(isAuthorized: true, premium: .premium)
    var recentlyPlayed: Result<[SpotifyRecentAlbum], StubError> = .success([])
    var storedSession = true
    var connection = SpotifyConnectionState.connected(premium: .free)

    func requestAuthorization() async throws -> SpotifyAuthResult { authResult }
    func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum] { try recentlyPlayed.get() }
    func hasStoredSession() async -> Bool { storedSession }
    func verifyConnection() async -> SpotifyConnectionState { connection }
}

enum Fixture {
    static func album(_ id: String, _ title: String = "Album", _ artist: String = "Artist") -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: title, artist: artist, coverUrl: nil, releaseDate: nil, genre: nil)
    }

    static let artist = AppleMusicArtistData(id: "ar", name: "Artist", imageUrl: nil, genres: [])
}
