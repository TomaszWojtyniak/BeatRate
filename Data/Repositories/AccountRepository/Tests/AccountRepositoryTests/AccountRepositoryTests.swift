import Foundation
import Models
import SwiftDataManager
import Testing
@testable import AccountRepository

@MainActor
struct AccountRepositoryTests {
    private let home = StubHomeRepository()
    private let music = StubMusicRepository()
    private let database = StubDatabaseFirebaseService()
    private let cache = SwiftDataManager.inMemory()

    private var repository: AccountRepository {
        AccountRepository(homeRepository: home, musicRepository: music, databaseFirebaseService: database, swiftDataManager: cache)
    }

    private func signIn() async throws {
        try await cache.setUserLoggedIn(userId: "u")
    }

    // MARK: - Rated albums

    @Test func `guest has no rated albums`() async throws {
        database.sortedRatings = [("a", 8)]

        #expect(try await repository.getUserRatedAlbums().isEmpty)
    }

    @Test func `rated albums keep the newest first order and carry the users rating`() async throws {
        try await signIn()
        database.sortedRatings = [("b", 9), ("a", 6)]
        home.cachedAlbums = ["a": Fixture.album("a")]
        home.remoteAlbums = ["b": Fixture.album("b")]

        let albums = try await repository.getUserRatedAlbums()

        #expect(albums.map(\.id) == ["b", "a"])
        #expect(albums.map(\.userRating) == [9, 6])
        #expect(home.fetchedIds == ["b"])
    }

    @Test func `rated album that cannot be loaded is left out`() async throws {
        try await signIn()
        database.sortedRatings = [("a", 6), ("gone", 4)]
        home.cachedAlbums = ["a": Fixture.album("a")]

        #expect(try await repository.getUserRatedAlbums().map(\.id) == ["a"])
    }

    @Test func `failed ratings read is passed on`() async throws {
        try await signIn()
        database.failsToReadRatings = true

        await #expect(throws: StubError.self) { try await repository.getUserRatedAlbums() }
    }

    // MARK: - Recently listened

    @Test func `recently listened albums are deduplicated and badged with ratings`() async throws {
        try await signIn()
        database.sortedRatings = [("a", 7)]
        music.recentlyPlayed = .success([Fixture.appleMusic("a"), Fixture.appleMusic("b"), Fixture.appleMusic("a")])

        let albums = try await repository.getRecentlyListenedAlbums(for: .spotify)

        #expect(albums.map(\.id) == ["a", "b"])
        #expect(albums.map(\.userRating) == [7, nil])
        #expect(music.requestedPlayers == [.spotify])
    }

    @Test(arguments: [false, true])
    func `recently listened albums are unrated for guests or when ratings are unreachable`(signedIn: Bool) async throws {
        if signedIn { try await signIn() }
        database.sortedRatings = [("a", 7)]
        database.failsToReadRatings = signedIn
        music.recentlyPlayed = .success([Fixture.appleMusic("a")])

        #expect(try await repository.getRecentlyListenedAlbums(for: .appleMusic).map(\.userRating) == [nil])
    }

    // Collapsing a failure into empty made rate-limited fetches look like no history.
    @Test func `failed recently listened fetch is passed on`() async {
        music.recentlyPlayed = .failure(StubError())

        await #expect(throws: StubError.self) { try await repository.getRecentlyListenedAlbums(for: .appleMusic) }
    }

    // MARK: - Account sections

    @Test func `signed in sections share one ratings read`() async throws {
        try await signIn()
        database.sortedRatings = [("b", 9), ("a", 6)]
        home.cachedAlbums = ["a": Fixture.album("a"), "b": Fixture.album("b")]
        music.recentlyPlayed = .success([Fixture.appleMusic("a"), Fixture.appleMusic("c")])

        let sections = try await repository.getAlbumSections(recentlyListenedFor: .appleMusic)

        #expect(sections.rated?.map(\.id) == ["b", "a"])
        #expect(sections.recentlyListened?.map(\.userRating) == [6, nil])
    }

    @Test func `guest sections have no ratings but still show recents`() async throws {
        music.recentlyPlayed = .success([Fixture.appleMusic("a")])

        let sections = try await repository.getAlbumSections(recentlyListenedFor: .appleMusic)

        #expect(sections.rated?.isEmpty == true)
        #expect(sections.recentlyListened?.map(\.id) == ["a"])
    }

    @Test func `no chosen player means no recents`() async throws {
        try await signIn()

        let sections = try await repository.getAlbumSections(recentlyListenedFor: nil)

        #expect(sections.recentlyListened?.isEmpty == true)
        #expect(music.requestedPlayers.isEmpty)
    }

    // nil, not empty, so the screen can keep what it already shows.
    @Test func `section that failed to load comes back as nil`() async throws {
        try await signIn()
        database.failsToReadRatings = true
        music.recentlyPlayed = .failure(StubError())

        let sections = try await repository.getAlbumSections(recentlyListenedFor: .spotify)

        #expect(sections.rated == nil)
        #expect(sections.recentlyListened == nil)
    }

    @Test func `unreachable ratings leave recents unrated`() async throws {
        try await signIn()
        database.failsToReadRatings = true
        music.recentlyPlayed = .success([Fixture.appleMusic("a")])

        let sections = try await repository.getAlbumSections(recentlyListenedFor: .appleMusic)

        #expect(sections.recentlyListened?.map(\.userRating) == [nil])
    }

    // MARK: - Favorites

    @Test func `guest has no favorites and cannot save them`() async throws {
        database.favoriteIds = ["a"]

        #expect(try await repository.getFavoriteAlbums().isEmpty)
        try await repository.setFavoriteAlbums(albumIds: ["a"])
        #expect(database.savedFavorites.isEmpty)
    }

    @Test func `favorites load in their saved order`() async throws {
        try await signIn()
        database.favoriteIds = ["b", "a"]
        home.cachedAlbums = ["a": Fixture.album("a")]
        home.remoteAlbums = ["b": Fixture.album("b")]

        #expect(try await repository.getFavoriteAlbums().map(\.id) == ["b", "a"])
    }

    // Favorites are re-saved from this list; dropping an id would delete the favorite.
    @Test func `unavailable favorite stays as a placeholder with its id`() async throws {
        try await signIn()
        database.favoriteIds = ["gone"]

        let favorite = try #require(try await repository.getFavoriteAlbums().first)

        #expect(favorite.id == "gone")
        #expect(favorite.appleMusicAlbumData.id == "gone")
        #expect(favorite.appleMusicAlbumData.title.isEmpty)
    }

    @Test func `favorites are saved for the signed in user`() async throws {
        try await signIn()

        try await repository.setFavoriteAlbums(albumIds: ["c", "a"])

        #expect(database.savedFavorites == [["c", "a"]])
    }
}
