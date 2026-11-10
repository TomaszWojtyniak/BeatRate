import Foundation
import Models
import SwiftData
import Synchronization
@testable import SwiftDataManager

struct StubError: Error {}

actor StubAppleUserIDStore: AppleUserIDStore {
    private(set) var deleteCount = 0
    private let failsToDelete: Bool

    init(failsToDelete: Bool = false) {
        self.failsToDelete = failsToDelete
    }

    func deleteAppleUserID() async throws {
        deleteCount += 1
        if failsToDelete { throw StubError() }
    }
}

/// Every reading is one second after the last, so "newest first" never ties.
final class TickingClock: Sendable {
    private let seconds = Mutex(0.0)

    func now() -> Date {
        Date(timeIntervalSince1970: seconds.withLock { $0 += 1; return $0 })
    }
}

enum Fixture {
    static func album(_ id: String, firebase: FirebaseAlbumData? = nil) -> AlbumModel {
        AlbumModel(id: id, appleMusicAlbumData: appleMusicAlbum(id), firebaseAlbumData: firebase)
    }

    static func appleMusicAlbum(_ id: String, title: String? = nil) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: title ?? "Album \(id)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }

    /// JSONEncoder refuses NaN, so this album can never be cached.
    static let unencodableAlbum = AppleMusicAlbumData(
        id: "nan", title: "Broken", artist: "Nobody", coverUrl: nil, releaseDate: nil, genre: nil,
        tracks: [Track(id: "t", title: "Track", trackNumber: 1, discNumber: 1, duration: .nan, isExplicit: false)]
    )

    static let firebase = FirebaseAlbumData(artist: "Artist", avgRating: 8.2, createdAt: 1, ratingCount: 3, title: "Album")

    @MainActor
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: SwiftDataManager.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}

/// A manager over its own in-memory store, so suites stay parallel-safe.
@MainActor
struct ManagerUnderTest {
    let manager: SwiftDataManager
    let keychain: StubAppleUserIDStore

    init(keychain: StubAppleUserIDStore = StubAppleUserIDStore(), clock: TickingClock? = nil) throws {
        self.keychain = keychain
        let now: @Sendable () -> Date = if let clock { { clock.now() } } else { Date.init }
        manager = SwiftDataManager(container: try Fixture.inMemoryContainer(), appleUserIDStore: keychain, now: now)
    }

    func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try manager.context.fetchCount(FetchDescriptor<T>())
    }

    func cachedAlbum(_ id: String) throws -> CachedAlbum? {
        try manager.context.fetch(FetchDescriptor<CachedAlbum>(predicate: #Predicate { $0.id == id })).first
    }
}
