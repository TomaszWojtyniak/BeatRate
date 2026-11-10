import Foundation
import Testing
@testable import Models

@MainActor
struct CachedAlbumTests {

    @Test func `undecodable apple music blob reads as a cache miss`() {
        let cached = CachedAlbum(id: "x", appleMusicAlbumDataData: ModelsFixture.undecodableBlob)

        #expect(cached.appleMusicAlbumData == nil)
        #expect(cached.toAlbumModel() == nil)
    }

    @Test func `undecodable firebase blob reads as nil without losing the album`() throws {
        let cached = CachedAlbum(
            id: "x",
            appleMusicAlbumDataData: try JSONEncoder().encode(ModelsFixture.album),
            firebaseAlbumDataData: ModelsFixture.undecodableBlob
        )

        #expect(cached.firebaseAlbumData == nil)
        // One bad blob must not discard both.
        #expect(cached.toAlbumModel()?.appleMusicAlbumData.title == "Blonde")
    }

    @Test func `album without community data has no firebase blob`() throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album))

        #expect(cached.firebaseAlbumDataData == nil)
        #expect(cached.firebaseAlbumData == nil)
    }

    @Test func `cached album turns back into the album model with the users rating`() throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album, firebaseAlbumData: ModelsFixture.firebaseAlbum))
        cached.userRating = 8.5

        let model = try #require(cached.toAlbumModel())

        #expect(model.id == "x")
        #expect(model.appleMusicAlbumData == ModelsFixture.album)
        #expect(model.firebaseAlbumData?.avgRating == 9.1)
        #expect(model.userRating == 8.5)
    }

    @Test func `album that will not encode is not cached`() {
        #expect(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.unencodableAlbum) == nil)
        #expect(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album, firebaseAlbumData: ModelsFixture.unencodableFirebaseAlbum) == nil)
    }

    @Test func `replacing the album rewrites the blob and refreshes the timestamp`() throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album))
        cached.lastUpdated = .distantPast

        cached.appleMusicAlbumData = ModelsFixture.album(id: "new")

        #expect(cached.appleMusicAlbumData?.id == "new")
        #expect(cached.lastUpdated > .distantPast)
    }

    @Test(arguments: [nil, ModelsFixture.unencodableAlbum])
    func `album that cannot be stored leaves the cached one untouched`(newValue: AppleMusicAlbumData?) throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album))
        cached.lastUpdated = .distantPast

        cached.appleMusicAlbumData = newValue

        #expect(cached.appleMusicAlbumData == ModelsFixture.album)
        #expect(cached.lastUpdated == .distantPast)
    }

    @Test func `replacing community data rewrites the blob and refreshes the timestamp`() throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album))
        cached.lastUpdated = .distantPast

        cached.firebaseAlbumData = ModelsFixture.firebaseAlbum

        #expect(cached.firebaseAlbumData?.ratingCount == 12)
        #expect(cached.lastUpdated > .distantPast)
    }

    @Test func `clearing community data drops the blob`() throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album, firebaseAlbumData: ModelsFixture.firebaseAlbum))
        cached.lastUpdated = .distantPast

        cached.firebaseAlbumData = nil

        #expect(cached.firebaseAlbumDataData == nil)
        #expect(cached.lastUpdated > .distantPast)
    }

    @Test func `community data that will not encode leaves the cached one untouched`() throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: ModelsFixture.album, firebaseAlbumData: ModelsFixture.firebaseAlbum))
        cached.lastUpdated = .distantPast

        cached.firebaseAlbumData = ModelsFixture.unencodableFirebaseAlbum

        #expect(cached.firebaseAlbumData?.avgRating == 9.1)
        #expect(cached.lastUpdated == .distantPast)
    }
}
