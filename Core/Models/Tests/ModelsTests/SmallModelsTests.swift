import Foundation
import Testing
@testable import Models

struct MusicPlayerTests {

    // Raw values are persisted in Firebase profiles, so they must never change.
    @Test(arguments: [
        (MusicPlayer.appleMusic, "appleMusic", "Apple Music"),
        (.spotify, "spotify", "Spotify"),
    ])
    func `player keeps its stored value and readable name`(player: MusicPlayer, rawValue: String, displayName: String) {
        #expect(player.rawValue == rawValue)
        #expect(player.displayName == displayName)
    }
}

struct UserRatingTests {

    @Test func `rating date comes from its timestamp`() {
        #expect(UserRating(rating: 8, timestamp: 86_400).date == Date(timeIntervalSince1970: 86_400))
    }

    @Test func `new rating is stamped with the current time`() {
        let before = Date()

        let rating = UserRating(rating: 8)

        #expect(rating.date >= before.addingTimeInterval(-1))
        #expect(rating.date <= Date())
    }
}

struct PlaceholderTests {

    @Test func `empty search has no results`() {
        #expect(MusicSearchResults.empty == MusicSearchResults(albums: [], artists: []))
    }

    @Test func `artist placeholder fills every detail section`() {
        let artist = AppleMusicArtistData.artistPlaceholder

        #expect(artist.albums == [.albumPlaceholder])
        #expect(artist.singles == [.albumPlaceholder])
        #expect(artist.latestRelease == .albumPlaceholder)
        #expect(artist.appleMusicUrl == nil)
    }

    @Test func `profile without connection flags leaves them unknown`() {
        let profile = FirebaseUserProfile(email: "a@b.c", firstName: "A", lastName: "B")

        #expect(profile.hasAppleMusicSubscription == nil)
        #expect(profile.hasSpotifyConnection == nil)
        #expect(profile.hasSpotifyPremium == nil)
        #expect(profile.mainMusicPlayer == nil)
    }

    @MainActor
    @Test func `new user starts signed out`() {
        let user = User()

        #expect(!user.isLoggedIn)
        #expect(user.userId.isEmpty)
    }
}
