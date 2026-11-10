import FirebaseService
import Foundation
import HomeRepository
import Models
import MusicRepository
import SpotifyService

struct StubError: Error {}

/// Main-actor classes because the protocols inherit their packages' default
/// main-actor isolation.
@MainActor
final class StubHomeRepository: HomeRepositoryProtocol {
    var cachedAlbums: [String: AlbumModel] = [:]
    var remoteAlbums: [String: AlbumModel] = [:]
    private(set) var fetchedIds: [String] = []

    func getCachedAlbum(albumId: String) async throws -> AlbumModel? { cachedAlbums[albumId] }

    func fetchAndCacheAlbum(albumId: String) async throws -> AlbumModel {
        fetchedIds.append(albumId)
        guard let album = remoteAlbums[albumId] else { throw StubError() }
        return album
    }

    func fetchHomeSections() async throws -> [HomeSection] { [] }
    func getUserRating(albumId: String) async throws -> Double? { nil }
    func saveAlbumRating(albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws {}
    func getFirebaseAlbumData(albumId: String) async throws -> FirebaseAlbumData? { nil }
    func invalidateUserCache() async {}
}

@MainActor
final class StubMusicRepository: MusicRepositoryProtocol {
    var recentlyPlayed: Result<[AppleMusicAlbumData], StubError> = .success([])
    private(set) var requestedPlayers: [MusicPlayer] = []

    func fetchRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AppleMusicAlbumData] {
        requestedPlayers.append(player)
        return try recentlyPlayed.get()
    }

    func requestMusicAuthorization() async -> MusicAuthorizationInfo { MusicAuthorizationInfo(isAuthorized: true, hasSubscription: true) }
    func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo { SpotifyAuthorizationInfo(isAuthorized: true, premium: .unknown) }
    func hasStoredSpotifySession() async -> Bool { false }
    func verifySpotifyConnection() async -> SpotifyConnectionState { .notConnected }
    func isAppleMusicAuthorized() async -> Bool { true }
    func isMusicKitAuthorizationDetermined() async -> Bool { true }
    func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData { throw StubError() }
    func getArtistData(byId artistId: String) async throws -> AppleMusicArtistData { throw StubError() }
    func getArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData { throw StubError() }
    func search(searchTerm: String) async throws -> MusicSearchResults { .empty }
}

@MainActor
final class StubDatabaseFirebaseService: DatabaseFirebaseServiceProtocol {
    /// Newest first, as the real service returns them.
    var sortedRatings: [(albumId: String, rating: Double)] = []
    var failsToReadRatings = false
    var favoriteIds: [String] = []
    private(set) var savedFavorites: [[String]] = []

    func getUserRatingsSorted(userId: String) async throws -> [(albumId: String, rating: Double)] {
        if failsToReadRatings { throw StubError() }
        return sortedRatings
    }

    func getAllUserRatings(userId: String) async throws -> [String: Double] {
        if failsToReadRatings { throw StubError() }
        return Dictionary(sortedRatings.map { ($0.albumId, $0.rating) }, uniquingKeysWith: { first, _ in first })
    }

    func getFavoriteAlbumIds(userId: String) async throws -> [String] { favoriteIds }

    func saveFavoriteAlbumIds(userId: String, albumIds: [String]) async throws {
        savedFavorites.append(albumIds)
    }

    func fetchSections() async throws -> [FirebaseAlbumSection] { [] }
    func fetchAlbumData(albumId: String) async throws -> FirebaseAlbumData? { nil }
    func getUserRating(userId: String, albumId: String) async throws -> Double? { nil }
    func getUserRatedAlbumIds(userId: String) async throws -> [String] { [] }
    func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws -> (avgRating: Double, ratingCount: Int) { (0, 0) }
    func removeUserRating(userId: String, albumId: String) async throws -> (avgRating: Double, ratingCount: Int) { (0, 0) }
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? { nil }
    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {}
    func deleteUserData(userId: String) async throws {}
}

enum Fixture {
    static func appleMusic(_ id: String) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: "Album \(id)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }

    static func album(_ id: String) -> AlbumModel {
        AlbumModel(id: id, appleMusicAlbumData: appleMusic(id), firebaseAlbumData: nil)
    }
}
