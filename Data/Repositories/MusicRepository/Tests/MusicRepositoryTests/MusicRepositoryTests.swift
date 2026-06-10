import Testing
import Models
import SpotifyService
@testable import MusicRepository

struct SpotifyAlbumMatcherTests {

    private func album(_ id: String, _ title: String, _ artist: String) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: title, artist: artist, coverUrl: nil, releaseDate: nil, genre: nil)
    }

    @Test func picksVerifiedMatchOverEarlierLooseResults() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Graduation", artist: "Kanye West")
        let candidates = [
            album("1", "Graduation Tribute", "Various Artists"),
            album("2", "Late Registration", "Kanye West"),
            album("3", "Graduation", "Kanye West")
        ]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "3")
    }

    @Test func ignoresCaseDiacriticsAndPunctuation() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "what's going on", artist: "marvin gaye")
        let candidates = [album("1", "What’s Going On", "Marvin Gaye")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "1")
    }

    @Test func acceptsEditionSuffixesOnEitherSide() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Random Access Memories", artist: "Daft Punk")
        let candidates = [album("1", "Random Access Memories (10th Anniversary Edition)", "Daft Punk")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "1")

        let spotifyDeluxe = SpotifyRecentAlbum(id: "s2", name: "Random Access Memories (Deluxe)", artist: "Daft Punk")
        let plain = [album("2", "Random Access Memories", "Daft Punk")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotifyDeluxe, in: plain)?.id == "2")
    }

    @Test func prefersExactTitleOverEditionVariant() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Random Access Memories", artist: "Daft Punk")
        let candidates = [
            album("1", "Random Access Memories (Drumless Edition)", "Daft Punk"),
            album("2", "Random Access Memories", "Daft Punk")
        ]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "2")
    }

    @Test func acceptsCollaboratingArtistListings() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Watch the Throne", artist: "JAY-Z")
        let candidates = [album("1", "Watch the Throne", "JAY-Z & Kanye West")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates)?.id == "1")
    }

    @Test func rejectsWrongArtistDespiteMatchingTitle() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Greatest Hits", artist: "Queen")
        let candidates = [album("1", "Greatest Hits", "ABBA")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates) == nil)
    }

    @Test func rejectsPartialWordTitlePrefix() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Up", artist: "Artist")
        let candidates = [album("1", "Uptown Special", "Artist")]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates) == nil)
    }

    @Test func returnsNilWhenNothingVerifies() {
        let spotify = SpotifyRecentAlbum(id: "s1", name: "Album X", artist: "Artist X")
        let candidates = [
            album("1", "Other Album", "Artist X"),
            album("2", "Album X", "Someone Else")
        ]
        #expect(SpotifyAlbumMatcher.bestMatch(for: spotify, in: candidates) == nil)
    }
}
