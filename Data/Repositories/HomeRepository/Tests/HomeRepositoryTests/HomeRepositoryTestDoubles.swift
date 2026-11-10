import FirebaseService
import Foundation
import Models
import MusicRepository
import SpotifyService
import Synchronization

struct StubError: Error {}

/// Main-actor classes because the protocols inherit their packages' default
/// main-actor isolation.
@MainActor
final class StubDatabaseFirebaseService: DatabaseFirebaseServiceProtocol {
    var sections: [FirebaseAlbumSection] = []
    var albums: [String: FirebaseAlbumData] = [:]
    var failingAlbumIds: Set<String> = []
    var userRatings: [String: Double] = [:]
    var failsToReadAllRatings = false
    var stats: (avgRating: Double, ratingCount: Int) = (0, 0)
    private(set) var ratingReads = 0
    private(set) var savedRatings: [(albumId: String, rating: Double, artist: String?, title: String?)] = []
    private(set) var removedRatings: [String] = []

    func fetchSections() async throws -> [FirebaseAlbumSection] { sections }

    func fetchAlbumData(albumId: String) async throws -> FirebaseAlbumData? {
        if failingAlbumIds.contains(albumId) { throw StubError() }
        return albums[albumId]
    }

    func getUserRating(userId: String, albumId: String) async throws -> Double? {
        ratingReads += 1
        return userRatings[albumId]
    }

    func getAllUserRatings(userId: String) async throws -> [String: Double] {
        if failsToReadAllRatings { throw StubError() }
        return userRatings
    }

    func saveUserRating(userId: String, albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws -> (avgRating: Double, ratingCount: Int) {
        savedRatings.append((albumId, rating, albumMetadata?.artist, albumMetadata?.title))
        return stats
    }

    func removeUserRating(userId: String, albumId: String) async throws -> (avgRating: Double, ratingCount: Int) {
        removedRatings.append(albumId)
        return stats
    }

    func getUserRatedAlbumIds(userId: String) async throws -> [String] { [] }
    func getUserRatingsSorted(userId: String) async throws -> [(albumId: String, rating: Double)] { [] }
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? { nil }
    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {}
    func getFavoriteAlbumIds(userId: String) async throws -> [String] { [] }
    func saveFavoriteAlbumIds(userId: String, albumIds: [String]) async throws {}
    func deleteUserData(userId: String) async throws {}
}

/// Serves catalog albums by id; any other id is a lookup failure.
@MainActor
final class StubMusicRepository: MusicRepositoryProtocol {
    var albums: [String: AppleMusicAlbumData] = [:]
    private(set) var albumLookups: [String] = []

    func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData {
        albumLookups.append(id)
        guard let album = albums[id] else { throw StubError() }
        return album
    }

    func requestMusicAuthorization() async -> MusicAuthorizationInfo { MusicAuthorizationInfo(isAuthorized: true, hasSubscription: true) }
    func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo { SpotifyAuthorizationInfo(isAuthorized: true, premium: .unknown) }
    func fetchRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AppleMusicAlbumData] { [] }
    func hasStoredSpotifySession() async -> Bool { false }
    func verifySpotifyConnection() async -> SpotifyConnectionState { .notConnected }
    func isAppleMusicAuthorized() async -> Bool { true }
    func isMusicKitAuthorizationDetermined() async -> Bool { true }
    func getArtistData(byId artistId: String) async throws -> AppleMusicArtistData { throw StubError() }
    func getArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData { throw StubError() }
    func search(searchTerm: String) async throws -> MusicSearchResults { .empty }
}

/// A clock the test moves by hand.
final class StubClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 1_000_000))

    func now() -> Date { current.withLock { $0 } }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

enum Fixture {
    static func appleMusic(_ id: String, title: String? = nil) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: title ?? "Album \(id)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }

    static func firebase(_ id: String, title: String? = nil, avg: Double = 7, count: Int = 2) -> FirebaseAlbumData {
        FirebaseAlbumData(artist: "Artist", avgRating: avg, createdAt: 1, ratingCount: count, title: title ?? "Album \(id)")
    }

    static func section(_ id: String, albums: [String], namePL: String? = nil) -> FirebaseAlbumSection {
        FirebaseAlbumSection(id: id, name: "Section \(id)", namePL: namePL, albums: albums, isActive: true)
    }
}
