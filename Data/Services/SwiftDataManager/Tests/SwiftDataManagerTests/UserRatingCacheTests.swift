import Foundation
import Models
import Testing
@testable import SwiftDataManager

@MainActor
struct UserRatingCacheTests {
    private let sut: ManagerUnderTest

    init() throws {
        sut = try ManagerUnderTest()
    }

    private var manager: SwiftDataManager { sut.manager }

    @Test func `rating is served from the cache for a week`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a"))

        try await manager.cacheUserRating(albumId: "a", rating: 9)

        #expect(try await manager.getCachedUserRating(albumId: "a") == 9)
    }

    @Test func `rating older than a week is a miss`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a"))
        try await manager.cacheUserRating(albumId: "a", rating: 9)
        try sut.cachedAlbum("a")?.userRatingUpdatedAt = Date().addingTimeInterval(-8 * 24 * 60 * 60)

        #expect(try await manager.getCachedUserRating(albumId: "a") == nil)
    }

    @Test func `unrated album has no cached rating`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a"))

        #expect(try await manager.getCachedUserRating(albumId: "a") == nil)
    }

    @Test func `rating for an uncached album is neither stored nor served`() async throws {
        try await manager.cacheUserRating(albumId: "missing", rating: 9)
        try await manager.removeCachedUserRating(albumId: "missing")

        #expect(try await manager.getCachedUserRating(albumId: "missing") == nil)
        #expect(try sut.count(CachedAlbum.self) == 0)
    }

    @Test func `removed rating is no longer served`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a"))
        try await manager.cacheUserRating(albumId: "a", rating: 9)

        try await manager.removeCachedUserRating(albumId: "a")

        #expect(try await manager.getCachedUserRating(albumId: "a") == nil)
        #expect(try sut.cachedAlbum("a")?.userRatingUpdatedAt == nil)
    }

    @Test func `bulk sync sets new ratings and clears ones removed elsewhere`() async throws {
        for id in ["a", "b", "c"] { try await manager.cacheAlbum(id: id, album: Fixture.album(id)) }
        try await manager.cacheUserRating(albumId: "b", rating: 4)
        try await manager.cacheUserRating(albumId: "c", rating: 6)

        try await manager.cacheUserRatings(["a": 8, "c": 6])

        #expect(try await manager.getCachedUserRating(albumId: "a") == 8)
        #expect(try await manager.getCachedUserRating(albumId: "b") == nil)
        #expect(try sut.cachedAlbum("b")?.userRatingUpdatedAt == nil)
        #expect(try await manager.getCachedUserRating(albumId: "c") == 6)
    }

    @Test func `bulk sync that changes nothing leaves timestamps alone`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a"))
        try await manager.cacheUserRating(albumId: "a", rating: 8)
        let stamped = try sut.cachedAlbum("a")?.userRatingUpdatedAt

        try await manager.cacheUserRatings(["a": 8])

        #expect(try sut.cachedAlbum("a")?.userRatingUpdatedAt == stamped)
    }
}
