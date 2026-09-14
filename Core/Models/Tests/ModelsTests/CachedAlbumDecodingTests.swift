import Foundation
import Testing
@testable import Models

/// A cache row written by an older schema must read as a miss. These used to be
/// `fatalError`, which meant the first release that changed `AppleMusicAlbumData`
/// would crash every existing install on launch with no way to ship a fix.
@MainActor
struct CachedAlbumDecodingTests {

    private static let album = AppleMusicAlbumData(
        id: "1440857781",
        title: "Blonde",
        artist: "Frank Ocean",
        coverUrl: nil,
        releaseDate: nil,
        genre: nil
    )

    @Test func undecodableAppleMusicBlobReadsAsNil() {
        let cached = CachedAlbum(id: "x", appleMusicAlbumDataData: Data("not json".utf8))

        #expect(cached.appleMusicAlbumData == nil)
        #expect(cached.toAlbumModel() == nil)
    }

    @Test func undecodableFirebaseBlobReadsAsNilWithoutLosingTheAlbum() throws {
        let encoded = try JSONEncoder().encode(Self.album)
        let cached = CachedAlbum(
            id: "x",
            appleMusicAlbumDataData: encoded,
            firebaseAlbumDataData: Data("not json".utf8)
        )

        #expect(cached.firebaseAlbumData == nil)
        // The album itself is still readable — one bad blob must not discard both.
        #expect(cached.toAlbumModel()?.appleMusicAlbumData.title == "Blonde")
    }

    @Test func roundTripsAValidAlbum() throws {
        let cached = try #require(CachedAlbum(id: "x", appleMusicAlbumData: Self.album))

        #expect(cached.appleMusicAlbumData == Self.album)
        #expect(cached.toAlbumModel()?.id == "x")
    }

    @Test func recentAlbumUndecodableBlobReadsAsNil() {
        let recent = RecentAlbum(id: "x", appleMusicAlbumDataData: Data("not json".utf8))

        #expect(recent.appleMusicAlbumData == nil)
        #expect(recent.toAppleMusicAlbumData() == nil)
    }

    @Test func recentAlbumRoundTrips() throws {
        let recent = try #require(RecentAlbum(id: "x", appleMusicAlbumData: Self.album))

        #expect(recent.toAppleMusicAlbumData() == Self.album)
    }
}
