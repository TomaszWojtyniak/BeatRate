import Foundation
import Models
import MusicKitService

nonisolated public enum FakeMusicKitError: Error, Equatable {
    /// MusicKit answers catalog calls only once access is granted.
    case notAuthorized
    case noFixture
}

/// MusicKit from the `music` fixture section: the access status before and after the
/// system prompt, and the albums the catalog knows. A catalog call without a fixture
/// is a network violation.
public actor FakeMusicKitService: MusicKitServiceProtocol {
    private var status: MusicAccessStatus
    private let answer: MusicAccessStatus
    private let hasSubscription: Bool
    private let albums: [String: AppleMusicAlbumData]

    init(status: MusicAccessStatus, answer: MusicAccessStatus, hasSubscription: Bool, albums: [String: AppleMusicAlbumData]) {
        self.status = status
        self.answer = answer
        self.hasSubscription = hasSubscription
        self.albums = albums
    }

    public func requestMusicAuthorization() async -> MusicAuthorizationResult {
        if status == .notDetermined { status = answer }
        return await MusicAuthorizationResult(status: status, hasSubscription: hasSubscription)
    }

    public func isAuthorized() async -> Bool { status == .authorized }
    public func isAuthorizationDetermined() async -> Bool { status != .notDetermined }

    public func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData? {
        guard status == .authorized else { throw FakeMusicKitError.notAuthorized }
        guard let album = albums[id] else { throw missing("album \(id)") }
        return album
    }

    public func fetchArtistData(byId artistId: String) async throws -> AppleMusicArtistData? { throw missing("artist \(artistId)") }
    public func fetchArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData? {
        throw missing("artist of album \(albumId)")
    }
    public func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] { throw missing("album search \(searchTerm)") }
    public func search(searchTerm: String) async throws -> MusicSearchResults { throw missing("search \(searchTerm)") }
    public func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData] { throw missing("recently played") }

    private func missing(_ request: String) -> FakeMusicKitError {
        NetworkGuard.record("missing music fixture: \(request)")
        return .noFixture
    }
}
