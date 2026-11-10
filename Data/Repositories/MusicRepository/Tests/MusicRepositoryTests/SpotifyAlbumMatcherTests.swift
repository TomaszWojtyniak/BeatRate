import Testing
import Models
import SpotifyService
@testable import MusicRepository

struct SpotifyAlbumMatcherTests {

    private func album(_ id: String, _ title: String, _ artist: String) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: title, artist: artist, coverUrl: nil, releaseDate: nil, genre: nil)
    }

    @Test func `verified match wins over earlier loose results`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Graduation", artist: "Kanye West")
        let candidates = [
            album("1", "Graduation Tribute", "Various Artists"),
            album("2", "Late Registration", "Kanye West"),
            album("3", "Graduation", "Kanye West")
        ]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "3")
    }

    @Test func `case, diacritics and punctuation are ignored`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "what's going on", artist: "marvin gaye")
        let candidates = [album("1", "What’s Going On", "Marvin Gaye")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "1")
    }

    @Test func `edition suffixes match on either side`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Random Access Memories", artist: "Daft Punk")
        let candidates = [album("1", "Random Access Memories (10th Anniversary Edition)", "Daft Punk")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "1")

        let spotifyDeluxe = SpotifyRecentAlbum(id: "s2", name: "Random Access Memories (Deluxe)", artist: "Daft Punk")
        let plain = [album("2", "Random Access Memories", "Daft Punk")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotifyDeluxe, in: plain)?.id == "2")
    }

    @Test func `exact title wins over an edition variant`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Random Access Memories", artist: "Daft Punk")
        let candidates = [
            album("1", "Random Access Memories (Drumless Edition)", "Daft Punk"),
            album("2", "Random Access Memories", "Daft Punk")
        ]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "2")
    }

    @Test func `collaboration listings match the lead artist`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Watch the Throne", artist: "JAY-Z")
        let candidates = [album("1", "Watch the Throne", "JAY-Z & Kanye West")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "1")
    }

    @Test func `same title by another artist is rejected`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Greatest Hits", artist: "Queen")
        let candidates = [album("1", "Greatest Hits", "ABBA")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates) == nil)
    }

    @Test func `partial word title prefix is rejected`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Up", artist: "Artist")
        let candidates = [album("1", "Uptown Special", "Artist")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates) == nil)
    }

    @Test func `nothing verified gives no match`() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Album X", artist: "Artist X")
        let candidates = [
            album("1", "Other Album", "Artist X"),
            album("2", "Album X", "Someone Else")
        ]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates) == nil)
    }
}
