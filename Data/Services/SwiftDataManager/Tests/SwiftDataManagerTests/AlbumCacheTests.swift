import Foundation
import Models
import Testing
@testable import SwiftDataManager

@MainActor
struct AlbumCacheTests {
    private let sut: ManagerUnderTest

    init() throws {
        sut = try ManagerUnderTest()
    }

    private var manager: SwiftDataManager { sut.manager }

    @Test func `cached album is read back with its community data`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a", firebase: Fixture.firebase))

        let album = try #require(try await manager.getCachedAlbum(id: "a"))

        #expect(album.appleMusicAlbumData == Fixture.appleMusicAlbum("a"))
        #expect(album.firebaseAlbumData?.avgRating == 8.2)
    }

    @Test func `album never cached reads as a miss`() async throws {
        #expect(try await manager.getCachedAlbum(id: "missing") == nil)
    }

    @Test func `album that will not encode is not cached`() async throws {
        let broken = AlbumModel(id: "nan", appleMusicAlbumData: Fixture.unencodableAlbum, firebaseAlbumData: nil)

        try await manager.cacheAlbum(id: "nan", album: broken)

        #expect(try sut.count(CachedAlbum.self) == 0)
    }

    @Test func `community data is updated in place`() async throws {
        try await manager.cacheAlbum(id: "a", album: Fixture.album("a"))

        try await manager.updateCachedAlbum(albumId: "a", firebaseData: Fixture.firebase)

        #expect(try await manager.getCachedAlbum(id: "a")?.firebaseAlbumData?.ratingCount == 3)
    }

    @Test func `community data for an uncached album is ignored`() async throws {
        try await manager.updateCachedAlbum(albumId: "missing", firebaseData: Fixture.firebase)

        #expect(try sut.count(CachedAlbum.self) == 0)
    }
}
