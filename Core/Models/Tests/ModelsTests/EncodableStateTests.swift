import Foundation
import Testing
@testable import Models

struct EncodableStateTests {
    private static func object(_ value: some Encodable) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] ?? [:]
    }

    @Test func `an album model encodes everything its screen shows`() throws {
        let album = AlbumModel(
            id: "1",
            appleMusicAlbumData: .albumPlaceholder,
            firebaseAlbumData: FirebaseAlbumData(artist: "A", avgRating: 8.5, createdAt: 1, ratingCount: 2, title: "T"),
            userRating: 7
        )

        let json = try Self.object(album)

        #expect(Set(json.keys) == ["id", "appleMusicAlbumData", "firebaseAlbumData", "userRating"])
        #expect(json["userRating"] as? Double == 7)
    }

    @Test func `a home section encodes its names and albums`() throws {
        let json = try Self.object(HomeSection(name: "New", analyticsName: "new", albums: [.albumPlaceholder]))

        #expect(json["name"] as? String == "New")
        #expect(json["analyticsName"] as? String == "new")
        #expect((json["albums"] as? [Any])?.count == 1)
    }

    @Test func `search results encode albums and artists`() throws {
        let json = try Self.object(MusicSearchResults(albums: [.albumPlaceholder], artists: []))

        #expect(Set(json.keys) == ["albums", "artists"])
    }
}
