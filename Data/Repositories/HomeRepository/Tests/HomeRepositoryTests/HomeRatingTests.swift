import Foundation
import Models
import SwiftDataManager
import Testing
@testable import HomeRepository

@MainActor
struct HomeRatingTests {
    private let database = StubDatabaseFirebaseService()
    private let music = StubMusicRepository()
    private let cache = SwiftDataManager.inMemory()
    private let clock = StubClock()
    private let repository: HomeRepository

    init() {
        let clock = clock
        repository = HomeRepository(databaseFirebaseService: database, musicRepository: music, swiftDataManager: cache, now: { clock.now() })
        music.albums = ["a": Fixture.appleMusic("a")]
    }

    private func signIn(_ userId: String = "u") async throws {
        try await cache.setUserLoggedIn(userId: userId)
    }

    @Test func `guest has no rating`() async throws {
        database.userRatings = ["a": 8]

        #expect(try await repository.getUserRating(albumId: "a") == nil)
        #expect(database.ratingReads == 0)
    }

    @Test func `cached rating is served without asking firebase`() async throws {
        try await signIn()
        _ = try await repository.fetchAndCacheAlbum(albumId: "a")
        try await cache.cacheUserRating(albumId: "a", rating: 6)

        #expect(try await repository.getUserRating(albumId: "a") == 6)
        #expect(database.ratingReads == 0)
    }

    @Test func `rating missing from the cache is read from firebase and cached`() async throws {
        try await signIn()
        _ = try await repository.fetchAndCacheAlbum(albumId: "a")
        database.userRatings = ["a": 9]

        #expect(try await repository.getUserRating(albumId: "a") == 9)
        #expect(try await cache.getCachedUserRating(albumId: "a") == 9)
    }

    @Test func `album the user never rated has no rating`() async throws {
        try await signIn()

        #expect(try await repository.getUserRating(albumId: "a") == nil)
        #expect(database.ratingReads == 1)
    }

    @Test func `guest cannot save a rating`() async {
        await #expect(throws: (any Error).self) { try await repository.saveAlbumRating(albumId: "a", rating: 8, albumMetadata: nil) }
        #expect(database.savedRatings.isEmpty)
    }

    @Test func `saving a rating stores it and refreshes the cached album stats`() async throws {
        try await signIn()
        database.albums = ["a": Fixture.firebase("a", avg: 5, count: 1)]
        _ = try await repository.fetchAndCacheAlbum(albumId: "a")
        database.stats = (avgRating: 6.5, ratingCount: 2)

        try await repository.saveAlbumRating(albumId: "a", rating: 8, albumMetadata: (artist: "Artist", title: "Album a"))

        #expect(database.savedRatings.map(\.rating) == [8])
        #expect(database.savedRatings.first?.title == "Album a")
        #expect(try await cache.getCachedUserRating(albumId: "a") == 8)
        let community = try await cache.getCachedAlbum(id: "a")?.firebaseAlbumData
        #expect(community?.avgRating == 6.5)
        #expect(community?.ratingCount == 2)
        #expect(community?.title == "Album a")
    }

    // A 0 would drag the average down and count as a vote.
    @Test(arguments: [0.0, -1.0])
    func `zero rating removes the rating instead of storing it`(rating: Double) async throws {
        try await signIn()
        database.albums = ["a": Fixture.firebase("a", avg: 8, count: 1)]
        _ = try await repository.fetchAndCacheAlbum(albumId: "a")
        try await cache.cacheUserRating(albumId: "a", rating: 8)
        database.stats = (avgRating: 0, ratingCount: 0)

        try await repository.saveAlbumRating(albumId: "a", rating: rating, albumMetadata: nil)

        #expect(database.removedRatings == ["a"])
        #expect(database.savedRatings.isEmpty)
        #expect(try await cache.getCachedUserRating(albumId: "a") == nil)
        #expect(try await cache.getCachedAlbum(id: "a")?.firebaseAlbumData?.ratingCount == 0)
    }

    @Test func `rating an album that is not cached still reaches firebase`() async throws {
        try await signIn()

        try await repository.saveAlbumRating(albumId: "x", rating: 7, albumMetadata: nil)
        try await repository.saveAlbumRating(albumId: "x", rating: 0, albumMetadata: nil)

        #expect(database.savedRatings.map(\.albumId) == ["x"])
        #expect(database.removedRatings == ["x"])
    }

    @Test func `signed in user is remembered for five minutes`() async throws {
        try await signIn()
        #expect(try await repository.getUserRating(albumId: "a") == nil)
        try await cache.setUserLoggedOut()

        clock.advance(by: 299)
        _ = try await repository.getUserRating(albumId: "a")
        let readsWhileCached = database.ratingReads
        clock.advance(by: 2)
        _ = try await repository.getUserRating(albumId: "a")

        #expect(readsWhileCached == 2)
        #expect(database.ratingReads == 2)
    }

    @Test func `forgetting the user rereads who is signed in`() async throws {
        try await signIn()
        _ = try await repository.getUserRating(albumId: "a")
        try await cache.setUserLoggedOut()

        await repository.invalidateUserCache()
        _ = try await repository.getUserRating(albumId: "a")

        #expect(database.ratingReads == 1)
    }
}
