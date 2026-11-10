import Foundation
import Models
import Testing
@testable import SwiftDataManager

@MainActor
struct RecentAlbumsTests {
    private let sut: ManagerUnderTest

    init() throws {
        sut = try ManagerUnderTest(clock: TickingClock())
    }

    private var manager: SwiftDataManager { sut.manager }

    @Test func `recent albums are listed newest first`() async throws {
        for id in ["a", "b", "c"] { try await manager.saveRecentAlbum(Fixture.appleMusicAlbum(id)) }

        #expect(try await manager.getRecentAlbums().map(\.id) == ["c", "b", "a"])
    }

    @Test func `viewing an album again moves it to the top with fresh details`() async throws {
        for id in ["a", "b"] { try await manager.saveRecentAlbum(Fixture.appleMusicAlbum(id)) }

        try await manager.saveRecentAlbum(Fixture.appleMusicAlbum("a", title: "Renamed"))

        let recents = try await manager.getRecentAlbums()
        #expect(recents.map(\.id) == ["a", "b"])
        #expect(recents.first?.title == "Renamed")
    }

    @Test func `only the five most recent albums are kept`() async throws {
        for id in ["1", "2", "3", "4", "5", "6"] { try await manager.saveRecentAlbum(Fixture.appleMusicAlbum(id)) }

        #expect(try await manager.getRecentAlbums().map(\.id) == ["6", "5", "4", "3", "2"])
        #expect(try sut.count(RecentAlbum.self) == 5)
    }

    @Test func `album that will not encode is not remembered`() async throws {
        try await manager.saveRecentAlbum(Fixture.unencodableAlbum)

        #expect(try await manager.getRecentAlbums().isEmpty)
    }

    @Test func `clearing recents empties the list`() async throws {
        try await manager.saveRecentAlbum(Fixture.appleMusicAlbum("a"))

        try await manager.clearRecentAlbums()

        #expect(try await manager.getRecentAlbums().isEmpty)
    }
}
