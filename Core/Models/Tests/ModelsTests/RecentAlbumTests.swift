import Foundation
import Testing
@testable import Models

@MainActor
struct RecentAlbumTests {

    @Test func `undecodable blob reads as nil`() {
        let recent = RecentAlbum(id: "x", appleMusicAlbumDataData: ModelsFixture.undecodableBlob)

        #expect(recent.appleMusicAlbumData == nil)
        #expect(recent.toAppleMusicAlbumData() == nil)
    }

    @Test func `recent album round trips`() throws {
        let recent = try #require(RecentAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album))

        #expect(recent.toAppleMusicAlbumData() == ModelsFixture.album)
    }

    @Test func `album that will not encode is not saved`() {
        #expect(RecentAlbum(id: "x", appleMusicAlbumData: ModelsFixture.unencodableAlbum) == nil)
    }

    @Test func `replacing the album moves it to the top of recents`() throws {
        let recent = try #require(RecentAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album))
        recent.addedAt = .distantPast

        recent.appleMusicAlbumData = ModelsFixture.album(id: "new")

        #expect(recent.appleMusicAlbumData?.id == "new")
        #expect(recent.addedAt > .distantPast)
    }

    @Test(arguments: [nil, ModelsFixture.unencodableAlbum])
    func `album that cannot be stored leaves the recent one untouched`(newValue: AppleMusicAlbumData?) throws {
        let recent = try #require(RecentAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album))
        recent.addedAt = .distantPast

        recent.appleMusicAlbumData = newValue

        #expect(recent.appleMusicAlbumData == ModelsFixture.album)
        #expect(recent.addedAt == .distantPast)
    }
}
