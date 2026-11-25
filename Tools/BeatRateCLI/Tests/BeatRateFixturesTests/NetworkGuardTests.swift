import Composition
import Foundation
import Testing
@testable import BeatRateFixtures

// Serialized: `NetworkGuard` keeps one list of violations for the whole process,
// so every test that records one lives here and runs alone.
@Suite(.serialized) struct NetworkGuardTests {
    @Test func `requests through the shared session are blocked and recorded`() async {
        NetworkGuard.reset()
        NetworkGuard.install()

        await #expect(throws: (any Error).self) {
            _ = try await URLSession.shared.data(from: URL(string: "https://example.com/ping")!)
        }
        #expect(NetworkGuard.violations == ["GET https://example.com/ping"])
    }

    @Test func `an album without a music fixture is a network violation`() async throws {
        NetworkGuard.reset()
        let edges = try await Edges.fixtures(try fixtures("{}"))

        await #expect(throws: (any Error).self) { try await edges.musicKit.fetchAlbumData(by: "missing") }
        #expect(NetworkGuard.violations == ["missing music fixture: album missing"])
    }

    @Test func `catalog calls without fixtures are network violations`() async throws {
        NetworkGuard.reset()
        let music = try await Edges.fixtures(try fixtures("{}")).musicKit

        _ = try? await music.fetchArtistData(byId: "a")
        _ = try? await music.fetchArtistData(forAlbumId: "1")
        _ = try? await music.searchAlbums(searchTerm: "x")
        _ = try? await music.search(searchTerm: "x")
        _ = try? await music.fetchRecentlyPlayedAlbums()

        #expect(NetworkGuard.violations == [
            "missing music fixture: artist a",
            "missing music fixture: artist of album 1",
            "missing music fixture: album search x",
            "missing music fixture: search x",
            "missing music fixture: recently played",
        ])
    }

    @Test func `a spotify request is a network violation`() async throws {
        NetworkGuard.reset()
        let edges = try await Edges.fixtures(try fixtures("{}"))

        await #expect(throws: (any Error).self) {
            _ = try await edges.spotifyTransport.send(URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!))
        }
        #expect(NetworkGuard.violations == ["missing http fixture: GET https://api.spotify.com/v1/me"])
        #expect(await edges.spotifyPresenter() == nil)
    }
}
