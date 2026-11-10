import Analytics
import CoreApp
import Foundation
import HomeUseCases
import Models

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

/// One stub for both album use cases. Main-actor because the protocols inherit
/// their package's default main-actor isolation.
@MainActor
final class StubAlbumUseCases: GetAlbumDetailsUseCaseProtocol, GetAlbumByIdUseCaseProtocol {
    var userRating: Result<Double?, StubError> = .success(nil)
    var failsToSave = false
    var updatedAlbum: Result<AlbumModel?, StubError> = .success(nil)
    var fullAlbum: Result<AlbumModel, StubError> = .failure(StubError())
    var albumById: Result<AlbumModel, StubError> = .failure(StubError())
    private(set) var savedRatings: [(rating: Double, artist: String?, title: String?)] = []

    func getUserRating(albumId: String) async throws -> Double? { try userRating.get() }

    func saveAlbumRating(albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws {
        if failsToSave { throw StubError() }
        savedRatings.append((rating, albumMetadata?.artist, albumMetadata?.title))
    }

    func getUpdatedAlbum(albumId: String) async throws -> AlbumModel? { try updatedAlbum.get() }
    func fetchFullAlbum(albumId: String) async throws -> AlbumModel { try fullAlbum.get() }
    func fetchAlbum(id albumId: String) async throws -> AlbumModel { try albumById.get() }
}

enum Fixture {
    static func album(
        tracks: [Track]? = nil,
        coverUrl: URL? = nil,
        appleMusicUrl: URL? = URL(string: "https://music.apple.com/album/1"),
        avgRating: Double? = nil
    ) -> AlbumModel {
        AlbumModel(
            id: "a",
            appleMusicAlbumData: AppleMusicAlbumData(
                id: "a", title: "Blonde", artist: "Frank Ocean", coverUrl: coverUrl,
                releaseDate: nil, genre: nil, tracks: tracks, appleMusicUrl: appleMusicUrl
            ),
            firebaseAlbumData: avgRating.map { FirebaseAlbumData(artist: "Frank Ocean", avgRating: $0, createdAt: 1, ratingCount: 1, title: "Blonde") }
        )
    }

    static func track(_ number: Int?, disc: Int? = 1, duration: TimeInterval? = 200) -> Track {
        Track(id: "\(disc ?? 0)-\(number ?? 0)", title: "Track \(number ?? 0)", trackNumber: number, discNumber: disc, duration: duration, isExplicit: false)
    }
}
