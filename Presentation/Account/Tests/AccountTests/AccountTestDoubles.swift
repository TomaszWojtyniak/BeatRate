import AccountUseCases
import Analytics
import AuthenticationServices
import Foundation
import LoginUseCases
import Models
import SearchUse

struct StubError: Error {}

/// Records every analytics call instead of sending it to Firebase.
@MainActor
final class StubAnalyticsBackend: AnalyticsBackend {
    private(set) var events: [(name: String, parameters: [String: Any]?)] = []

    func logEvent(_ name: String, parameters: [String: Any]?) {
        events.append((name, parameters))
    }

    func setConsent(analyticsGranted: Bool) {}
    func setCollectionEnabled(_ enabled: Bool) {}
    func resetData() {}
    func setUserProperty(_ value: String?, forName name: String) {}
    func setUserID(_ userId: String?) {}

    /// Whether `event` was logged with exactly its name and parameters.
    func logged(_ event: AnalyticsEvent) -> Bool {
        let expected = event.parameters as NSDictionary
        return events.contains { $0.name == event.name && (($0.parameters ?? [:]) as NSDictionary) == expected }
    }
}

/// An opted-in analytics manager over its own defaults suite, recording into a stub.
@MainActor
func makeAnalytics() -> (AnalyticsManager, StubAnalyticsBackend) {
    let backend = StubAnalyticsBackend()
    let manager = AnalyticsManager(defaults: UserDefaults(suiteName: "Analytics.\(UUID())")!, backend: backend)
    manager.setAnalyticsEnabled(true)
    return (manager, backend)
}

/// Main-actor classes because the use-case protocols inherit their packages'
/// default main-actor isolation.
@MainActor
final class StubLoginUseCases: GetLoginUseCaseProtocol, SetLoginUseCaseProtocol {
    var profile: Result<FirebaseUserProfile?, StubError> = .success(nil)
    var failsToSave = false
    private(set) var savedProfiles: [FirebaseUserProfile] = []

    func getCurrentNonce() async -> String { "nonce" }
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? { try profile.get() }
    func performCompleteLogin(authResult: ASAuthorization) async throws -> String { "" }

    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {
        if failsToSave { throw StubError() }
        savedProfiles.append(profile)
    }
}

@MainActor
final class StubAccountUseCases: GetAccountUseCaseProtocol, SetAccountUseCaseProtocol {
    var userId: String? = "u"
    var rated: Result<[AlbumModel]?, StubError> = .success([])
    var recentlyListened: Result<[AlbumModel]?, StubError> = .success([])
    var favorites: Result<[AlbumModel], StubError> = .success([])
    var failsToSaveFavorites = false
    private(set) var sectionPlayers: [MusicPlayer?] = []
    private(set) var recentsPlayers: [MusicPlayer] = []
    private(set) var savedFavoriteIds: [[String]] = []

    func getCurrentUserId() async throws -> String? { userId }
    func getUserRatedAlbums() async throws -> [AlbumModel] { try rated.get() ?? [] }

    func getRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AlbumModel] {
        recentsPlayers.append(player)
        return try recentlyListened.get() ?? []
    }

    func getAlbumSections(recentlyListenedFor player: MusicPlayer?) async throws -> (rated: [AlbumModel]?, recentlyListened: [AlbumModel]?) {
        sectionPlayers.append(player)
        return (try? rated.get() ?? nil, try? recentlyListened.get() ?? nil)
    }

    func getFavoriteAlbums() async throws -> [AlbumModel] { try favorites.get() }

    func setFavoriteAlbums(albumIds: [String]) async throws {
        if failsToSaveFavorites { throw StubError() }
        savedFavoriteIds.append(albumIds)
    }
}

@MainActor
final class StubSearchUseCase: GetSearchUseCaseProtocol {
    var results: [String: MusicSearchResults] = [:]
    var failingTerms: Set<String> = []
    private(set) var searchedTerms: [String] = []

    func search(searchTerm: String) async throws -> MusicSearchResults {
        searchedTerms.append(searchTerm)
        if failingTerms.contains(searchTerm) { throw StubError() }
        return results[searchTerm] ?? .empty
    }
}

enum Fixture {
    static func appleMusic(_ id: String) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: "Album \(id)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }

    static func album(_ id: String, rating: Double? = nil) -> AlbumModel {
        AlbumModel(id: id, appleMusicAlbumData: appleMusic(id), firebaseAlbumData: nil, userRating: rating)
    }
}
