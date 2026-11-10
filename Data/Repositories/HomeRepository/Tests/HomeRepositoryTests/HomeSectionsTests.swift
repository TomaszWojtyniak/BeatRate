import Foundation
import Models
import SwiftDataManager
import Testing
@testable import HomeRepository

@MainActor
struct HomeSectionsTests {
    private let database = StubDatabaseFirebaseService()
    private let music = StubMusicRepository()
    private let cache = SwiftDataManager.inMemory()
    private let repository: HomeRepository

    init() {
        repository = HomeRepository(databaseFirebaseService: database, musicRepository: music, swiftDataManager: cache)
        music.albums = ["a": Fixture.appleMusic("a"), "b": Fixture.appleMusic("b"), "c": Fixture.appleMusic("c")]
    }

    @Test func `sections are built from firebase in order with their albums`() async throws {
        database.sections = [Fixture.section("1", albums: ["b", "a"], namePL: "Pierwsza"), Fixture.section("2", albums: ["c"])]
        database.albums = ["a": Fixture.firebase("a", avg: 9)]

        let sections = try await repository.fetchHomeSections()

        #expect(sections.map(\.name) == ["Section 1", "Section 2"])
        #expect(sections[0].namePL == "Pierwsza")
        #expect(sections.map { $0.albums.map(\.id) } == [["b", "a"], ["c"]])
        #expect(sections[0].albums[1].firebaseAlbumData?.avgRating == 9)
    }

    @Test func `fresh cache is served without asking firebase again`() async throws {
        database.sections = [Fixture.section("1", albums: ["a"])]
        _ = try await repository.fetchHomeSections()
        database.sections = [Fixture.section("new", albums: ["b"])]

        let sections = try await repository.fetchHomeSections()

        #expect(sections.map(\.name) == ["Section 1"])
    }

    // Built while MusicKit was refused; serving it would keep Home blank for a day.
    @Test func `cached sections without any album are rebuilt`() async throws {
        database.sections = [Fixture.section("1", albums: ["missing"])]
        _ = try await repository.fetchHomeSections()
        database.sections = [Fixture.section("1", albums: ["a"])]

        let sections = try await repository.fetchHomeSections()

        #expect(sections.first?.albums.map(\.id) == ["a"])
    }

    @Test func `duplicate album ids appear once`() async throws {
        database.sections = [Fixture.section("1", albums: ["a", "b", "a"])]

        #expect(try await repository.fetchHomeSections().first?.albums.map(\.id) == ["a", "b"])
    }

    @Test func `album the catalog cannot find is left out`() async throws {
        database.sections = [Fixture.section("1", albums: ["a", "missing", "b"])]

        #expect(try await repository.fetchHomeSections().first?.albums.map(\.id) == ["a", "b"])
    }

    @Test func `album whose firebase entry names another album is left out`() async throws {
        database.sections = [Fixture.section("1", albums: ["a", "b"])]
        database.albums = ["a": Fixture.firebase("a", title: "Something Else")]

        #expect(try await repository.fetchHomeSections().first?.albums.map(\.id) == ["b"])
    }

    // Guests cannot seed albums/<id>, so a failed community read must not hide the album.
    @Test func `album keeps its place when its community data cannot be read`() async throws {
        database.sections = [Fixture.section("1", albums: ["a"])]
        database.failingAlbumIds = ["a"]

        let album = try #require(try await repository.fetchHomeSections().first?.albums.first)

        #expect(album.id == "a")
        #expect(album.firebaseAlbumData == nil)
    }

    @Test func `already cached album is not looked up again`() async throws {
        _ = try await repository.fetchAndCacheAlbum(albumId: "a")
        database.sections = [Fixture.section("1", albums: ["a"])]

        _ = try await repository.fetchHomeSections()

        #expect(music.albumLookups == ["a"])
    }

    @Test func `guest sees no personal ratings`() async throws {
        database.sections = [Fixture.section("1", albums: ["a"])]
        database.userRatings = ["a": 8]

        #expect(try await repository.fetchHomeSections().first?.albums.first?.userRating == nil)
    }

    @Test func `signed in user sees their ratings and the cache learns them`() async throws {
        try await cache.setUserLoggedIn(userId: "u")
        database.sections = [Fixture.section("1", albums: ["a", "b"])]
        database.userRatings = ["a": 8]

        let albums = try #require(try await repository.fetchHomeSections().first?.albums)

        #expect(albums.map(\.userRating) == [8, nil])
        #expect(try await cache.getCachedUserRating(albumId: "a") == 8)
    }

    @Test func `offline ratings read keeps whatever the sections already had`() async throws {
        try await cache.setUserLoggedIn(userId: "u")
        database.sections = [Fixture.section("1", albums: ["a"])]
        database.failsToReadAllRatings = true

        let albums = try #require(try await repository.fetchHomeSections().first?.albums)

        #expect(albums.map(\.id) == ["a"])
    }

    @Test func `album lookup failure is passed on when fetching a single album`() async {
        await #expect(throws: StubError.self) { try await repository.fetchAndCacheAlbum(albumId: "missing") }
    }

    @Test func `cached album and community data are read through`() async throws {
        database.albums = ["a": Fixture.firebase("a")]
        _ = try await repository.fetchAndCacheAlbum(albumId: "a")

        #expect(try await repository.getCachedAlbum(albumId: "a")?.id == "a")
        #expect(try await repository.getFirebaseAlbumData(albumId: "a")?.ratingCount == 2)
    }
}
