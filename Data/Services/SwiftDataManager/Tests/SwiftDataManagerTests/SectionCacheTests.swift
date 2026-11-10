import Foundation
import Models
import SwiftData
import Testing
@testable import SwiftDataManager

@MainActor
struct SectionCacheTests {
    private let sut: ManagerUnderTest

    init() throws {
        sut = try ManagerUnderTest()
    }

    private var manager: SwiftDataManager { sut.manager }

    @Test func `sections come back in order with their albums and titles`() async throws {
        try await manager.cacheSections([
            HomeSection(name: "New", namePL: "Nowe", albums: [Fixture.album("b"), Fixture.album("a")]),
            HomeSection(name: "Top", albums: [Fixture.album("c")]),
        ])

        let sections = try await manager.getCachedSections()

        #expect(sections.map(\.name) == ["New", "Top"])
        #expect(sections[0].namePL == "Nowe")
        #expect(sections.map { $0.albums.map(\.id) } == [["b", "a"], ["c"]])
    }

    @Test func `caching sections replaces the previous ones`() async throws {
        try await manager.cacheSections([HomeSection(name: "Old", albums: [])])

        try await manager.cacheSections([HomeSection(name: "New", albums: [])])

        #expect(try await manager.getCachedSections().map(\.name) == ["New"])
    }

    @Test func `album shared by two sections is stored once and keeps its rating`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a"))
        try await manager.cacheUserRating(albumId: "a", rating: 7)

        try await manager.cacheSections([
            HomeSection(name: "New", albums: [Fixture.album("a")]),
            HomeSection(name: "Top", albums: [Fixture.album("a")]),
        ])

        #expect(try sut.count(CachedAlbum.self) == 1)
        #expect(try await manager.getCachedSections().flatMap(\.albums).map(\.userRating) == [7, 7])
    }

    @Test func `album that will not encode is left out of its section`() async throws {
        let broken = AlbumModel(id: "nan", appleMusicAlbumData: Fixture.unencodableAlbum, firebaseAlbumData: nil)

        try await manager.cacheSections([HomeSection(name: "New", albums: [broken, Fixture.album("a")])])

        #expect(try await manager.getCachedSections().first?.albums.map(\.id) == ["a"])
    }

    @Test func `empty cache is not valid`() async {
        #expect(await !manager.isCacheValid())
    }

    @Test func `freshly cached sections are valid`() async throws {
        try await manager.cacheSections([HomeSection(name: "New", albums: [])])

        #expect(await manager.isCacheValid())
    }

    @Test func `one section older than a day invalidates the cache`() async throws {
        try await manager.cacheSections([HomeSection(name: "New", albums: []), HomeSection(name: "Top", albums: [])])
        let sections = try manager.context.fetch(FetchDescriptor<CachedSection>())
        sections[0].lastUpdated = Date().addingTimeInterval(-86_401)

        #expect(await !manager.isCacheValid())
    }

    @Test func `clearing the cache keeps recently viewed albums`() async throws {
        try await manager.cacheSections([HomeSection(name: "New", albums: [Fixture.album("a")])])
        try await manager.saveRecentAlbum(Fixture.appleMusicAlbum("r"))

        try await manager.clearCache()

        #expect(try sut.count(CachedSection.self) == 0)
        #expect(try sut.count(CachedAlbum.self) == 0)
        #expect(try await manager.getRecentAlbums().map(\.id) == ["r"])
    }
}
