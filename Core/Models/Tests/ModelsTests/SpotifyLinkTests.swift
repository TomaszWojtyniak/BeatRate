import Foundation
import Testing
@testable import Models

struct SpotifyLinkTests {

    @Test func `search url is built from title and artist`() throws {
        let url = try #require(SpotifyLink.search(title: "Blonde", artist: "Frank Ocean"))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde%20Frank%20Ocean")
    }

    @Test func `reserved characters are percent encoded`() throws {
        let url = try #require(SpotifyLink.search(title: "Sgt. Pepper's", artist: "The Beatles"))
        #expect(url.absoluteString.contains("Sgt."))
        #expect(!url.absoluteString.contains(" "))
    }

    @Test func `surrounding whitespace is trimmed`() throws {
        let url = try #require(SpotifyLink.search(title: "  Blonde  ", artist: " Frank Ocean "))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde%20Frank%20Ocean")
    }

    @Test func `empty title and artist give no url`() {
        #expect(SpotifyLink.search(title: "   ", artist: "") == nil)
    }

    @Test func `title alone is enough`() throws {
        let url = try #require(SpotifyLink.search(title: "Blonde", artist: ""))
        #expect(url.absoluteString == "https://open.spotify.com/search/Blonde")
    }
}
