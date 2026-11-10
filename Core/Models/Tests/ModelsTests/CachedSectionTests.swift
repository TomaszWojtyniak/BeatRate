import Foundation
import SwiftData
import Testing
@testable import Models

@MainActor
struct CachedSectionTests {

    @Test func `section without albums reads back empty with its titles`() {
        let section = CachedSection(sectionId: "s", name: "New", namePL: "Nowe", order: 0).toHomeSection()

        #expect(section.albums.isEmpty)
        #expect(section.name == "New")
        #expect(section.namePL == "Nowe")
    }

    @Test func `albums come back in the stored order skipping missing and unreadable ones`() throws {
        let container = try ModelsFixture.makeContainer()
        let context = container.mainContext
        let first = try #require(CachedAlbum(id: "a", appleMusicAlbumData: ModelsFixture.album(id: "a")))
        let second = try #require(CachedAlbum(id: "b", appleMusicAlbumData: ModelsFixture.album(id: "b")))
        let broken = CachedAlbum(id: "c", appleMusicAlbumDataData: ModelsFixture.undecodableBlob)
        let section = CachedSection(sectionId: "s", name: "New", order: 0, orderedAlbumIds: ["b", "missing", "c", "a"])
        context.insert(section)
        section.albums = [first, second, broken]

        let albums = section.toHomeSection().albums

        #expect(albums.map(\.id) == ["b", "a"])
    }
}
