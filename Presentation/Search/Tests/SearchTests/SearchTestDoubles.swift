import Analytics
import Foundation
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

/// One stub for the four search use cases. Main-actor because the protocols
/// inherit their package's default main-actor isolation.
@MainActor
final class StubSearchUseCases: GetSearchUseCaseProtocol, GetRecentAlbumsUseCaseProtocol, SaveRecentAlbumUseCaseProtocol, ClearRecentAlbumsUseCaseProtocol {
    var results: [String: MusicSearchResults] = [:]
    var failingTerms: Set<String> = []
    var recents: [AppleMusicAlbumData] = []
    private(set) var searchedTerms: [String] = []

    func search(searchTerm: String) async throws -> MusicSearchResults {
        searchedTerms.append(searchTerm)
        if failingTerms.contains(searchTerm) { throw StubError() }
        return results[searchTerm] ?? .empty
    }

    func fetchRecentAlbums() async -> [AppleMusicAlbumData] { recents }
    func save(album: AppleMusicAlbumData) async { recents.insert(album, at: 0) }
    func clearAll() async { recents = [] }
}
