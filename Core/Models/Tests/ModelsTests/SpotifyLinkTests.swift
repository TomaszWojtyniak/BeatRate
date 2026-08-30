import Foundation
import Testing
@testable import Models

struct SpotifyLinkTests {

    @Test func buildsSearchURLFromTitleAndArtist() throws {
        let url = try #require(SpotifyLink.search(title: "Blonde", artist: "Frank Ocean"))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde%20Frank%20Ocean")
    }

    @Test func percentEncodesReservedCharacters() throws {
        let url = try #require(SpotifyLink.search(title: "Sgt. Pepper's", artist: "The Beatles"))
        #expect(url.absoluteString.contains("Sgt."))
        #expect(!url.absoluteString.contains(" "))
    }

    @Test func trimsSurroundingWhitespace() throws {
        let url = try #require(SpotifyLink.search(title: "  Blonde  ", artist: " Frank Ocean "))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde%20Frank%20Ocean")
    }

    @Test func emptyTitleAndArtistYieldsNil() {
        #expect(SpotifyLink.search(title: "   ", artist: "") == nil)
    }

    @Test func titleAloneIsEnough() throws {
        let url = try #require(SpotifyLink.search(title: "Blonde", artist: ""))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde")
    }
}
