import Foundation
import Testing
@testable import MusicKitService

struct AppleMusicAPITests {

    @Test func `album tracks endpoint asks for the largest page in the storefront`() {
        let url = AppleMusicAPI.albumTracks(storefront: "pl", albumId: "123")

        #expect(url.absoluteString == "https://api.music.apple.com/v1/catalog/pl/albums/123/tracks?limit=300")
    }

    @Test func `next page path resolves against the api host`() {
        let url = AppleMusicAPI.nextPage("/v1/catalog/pl/albums/123/tracks?offset=300")

        #expect(url?.absoluteString == "https://api.music.apple.com/v1/catalog/pl/albums/123/tracks?offset=300")
    }
}

struct AppleMusicTracksPageTests {

    private static func decode(_ json: String) throws -> AppleMusicTracksPage {
        try JSONDecoder().decode(AppleMusicTracksPage.self, from: Data(json.utf8))
    }

    @Test func `track attributes map onto the app model`() throws {
        let page = try Self.decode(#"""
        {"data":[{"id":"t1","attributes":{"name":"Nikes","trackNumber":1,"discNumber":1,"durationInMillis":314500,"contentRating":"explicit"}}]}
        """#)

        let track = try #require(page.tracks.first)

        #expect(track.id == "t1")
        #expect(track.title == "Nikes")
        #expect(track.trackNumber == 1)
        #expect(track.discNumber == 1)
        #expect(track.duration == 314.5)
        #expect(track.isExplicit)
        #expect(page.next == nil)
    }

    @Test func `track without optional attributes is clean and has no duration`() throws {
        let track = try #require(try Self.decode(#"{"data":[{"id":"t","attributes":{"name":"Intro"}}]}"#).tracks.first)

        #expect(track.duration == nil)
        #expect(track.trackNumber == nil)
        #expect(!track.isExplicit)
    }

    @Test(arguments: ["clean", "notExplicit"])
    func `only the explicit rating marks a track explicit`(rating: String) throws {
        let json = #"{"data":[{"id":"t","attributes":{"name":"Intro","contentRating":"\#(rating)"}}]}"#

        #expect(try Self.decode(json).tracks.first?.isExplicit == false)
    }
}
