import Foundation
import Models
import MusicKit
import SpotifyService
import Testing
@testable import MusicRepository

@MainActor
struct MusicRepositoryTests {
    private let musicKit = StubMusicKitService()
    private let spotify = StubSpotifyService()

    private var repository: MusicRepository {
        MusicRepository(musicKitService: musicKit, spotifyService: spotify)
    }

    // MARK: - Apple Music authorization

    @Test func `granted access is remembered with its subscription`() async {
        musicKit.hasSubscription = true
        let repository = repository

        let first = await repository.requestMusicAuthorization()
        musicKit.hasSubscription = false
        let second = await repository.requestMusicAuthorization()

        #expect(first.isAuthorized && first.hasSubscription)
        #expect(second.isAuthorized && second.hasSubscription)
        #expect(musicKit.authorizationRequests == 1)
    }

    @Test(arguments: [MusicAuthorization.Status.denied, .restricted, .notDetermined])
    func `refused access is reported and asked again next time`(status: MusicAuthorization.Status) async {
        musicKit.authorizationStatus = status
        let repository = repository

        let result = await repository.requestMusicAuthorization()
        _ = await repository.requestMusicAuthorization()

        #expect(!result.isAuthorized)
        #expect(musicKit.authorizationRequests == 2)
    }

    @Test(arguments: [true, false])
    func `authorization state is read from music kit`(state: Bool) async {
        musicKit.authorized = state
        musicKit.determined = !state

        #expect(await repository.isAppleMusicAuthorized() == state)
        #expect(await repository.isMusicKitAuthorizationDetermined() == !state)
    }

    // MARK: - Catalog

    @Test func `album is looked up by id`() async throws {
        musicKit.albums = ["a": Fixture.album("a")]

        #expect(try await repository.getAlbumDataById("a") == Fixture.album("a"))
    }

    @Test func `missing album is an error naming it`() async {
        await #expect {
            try await repository.getAlbumDataById("missing")
        } throws: { error in
            (error as? AlbumNotFoundError)?.errorDescription?.contains("missing") == true
        }
    }

    @Test func `artist is looked up by id or by album`() async throws {
        musicKit.artist = Fixture.artist

        #expect(try await repository.getArtistData(byId: "ar") == Fixture.artist)
        #expect(try await repository.getArtistData(forAlbumId: "a") == Fixture.artist)
    }

    @Test func `missing artist is an error naming the lookup`() async {
        await #expect { try await repository.getArtistData(byId: "ar") } throws: { error in
            (error as? ArtistNotFoundError)?.errorDescription?.contains("ar") == true
        }
        await #expect(throws: ArtistNotFoundError.self) { try await repository.getArtistData(forAlbumId: "a") }
    }

    @Test func `search returns the catalog results`() async throws {
        musicKit.searchResults = MusicSearchResults(albums: [Fixture.album("a")], artists: [Fixture.artist])

        #expect(try await repository.search(searchTerm: "a") == musicKit.searchResults)
    }

    // MARK: - Spotify

    @Test func `spotify authorization carries the premium status`() async throws {
        spotify.authResult = SpotifyAuthResult(isAuthorized: true, premium: .free)

        let info = try await repository.requestSpotifyAuthorization()

        #expect(info.isAuthorized)
        #expect(info.premium == .free)
    }

    @Test func `spotify session state comes from the service`() async {
        spotify.storedSession = false
        spotify.connection = .needsReauth

        #expect(await !repository.hasStoredSpotifySession())
        #expect(await repository.verifySpotifyConnection() == .needsReauth)
    }

    // MARK: - Recently listened

    @Test func `apple music recents come straight from music kit`() async throws {
        musicKit.recentlyPlayed = .success([Fixture.album("a"), Fixture.album("b")])

        #expect(try await repository.fetchRecentlyListenedAlbums(for: .appleMusic).map(\.id) == ["a", "b"])
    }

    @Test func `spotify recents are matched to the apple music catalog in order`() async throws {
        spotify.recentlyPlayed = .success([
            SpotifyRecentAlbum(id: "s1", name: "Blonde", artist: "Frank Ocean"),
            SpotifyRecentAlbum(id: "s2", name: "Unknown", artist: "Nobody"),
            SpotifyRecentAlbum(id: "s3", name: "Graduation", artist: "Kanye West"),
            SpotifyRecentAlbum(id: "s4", name: "Offline", artist: "Band"),
        ])
        musicKit.catalogMatches = [
            "Blonde Frank Ocean": [Fixture.album("am1", "Blonde", "Frank Ocean")],
            "Unknown Nobody": [Fixture.album("x", "Something Else", "Nobody")],
            "Graduation Kanye West": [Fixture.album("am3", "Graduation", "Kanye West")],
        ]
        musicKit.failingSearchTerms = ["Offline Band"]

        let albums = try await repository.fetchRecentlyListenedAlbums(for: .spotify)

        #expect(albums.map(\.id) == ["am1", "am3"])
    }

    @Test func `spotify album without an artist is searched by title alone`() async throws {
        spotify.recentlyPlayed = .success([SpotifyRecentAlbum(id: "s", name: "Blonde", artist: "")])

        _ = try await repository.fetchRecentlyListenedAlbums(for: .spotify)

        #expect(musicKit.searchedTerms == ["Blonde"])
    }

    @Test func `empty listening history is not an error`() async throws {
        #expect(try await repository.fetchRecentlyListenedAlbums(for: .appleMusic).isEmpty)
    }

    // Rethrown so callers can tell a failed fetch from an empty history.
    @Test(arguments: Models.MusicPlayer.allCases)
    func `failed recents fetch is passed on`(player: Models.MusicPlayer) async {
        musicKit.recentlyPlayed = .failure(StubError())
        spotify.recentlyPlayed = .failure(StubError())

        await #expect(throws: StubError.self) { try await repository.fetchRecentlyListenedAlbums(for: player) }
    }

    @Test func `authorization info keeps what it is given`() {
        let info = MusicAuthorizationInfo(isAuthorized: true, hasSubscription: false)

        #expect(info.isAuthorized)
        #expect(!info.hasSubscription)
    }
}
