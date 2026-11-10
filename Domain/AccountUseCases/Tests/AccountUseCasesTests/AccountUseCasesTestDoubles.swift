import AccountRepository
import Foundation
import Models

struct StubError: Error {}

/// Main-actor class because the protocol inherits its package's default
/// main-actor isolation.
@MainActor
final class StubAccountRepository: AccountRepositoryProtocol {
    var rated: [AlbumModel] = []
    var recentlyListened: [AlbumModel] = []
    var favorites: [AlbumModel] = []
    private(set) var requestedPlayers: [MusicPlayer?] = []
    private(set) var savedFavorites: [[String]] = []

    func getUserRatedAlbums() async throws -> [AlbumModel] { rated }

    func getRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AlbumModel] {
        requestedPlayers.append(player)
        return recentlyListened
    }

    func getAlbumSections(recentlyListenedFor player: MusicPlayer?) async throws -> (rated: [AlbumModel]?, recentlyListened: [AlbumModel]?) {
        requestedPlayers.append(player)
        return (rated, recentlyListened)
    }

    func getFavoriteAlbums() async throws -> [AlbumModel] { favorites }

    func setFavoriteAlbums(albumIds: [String]) async throws {
        savedFavorites.append(albumIds)
    }
}
