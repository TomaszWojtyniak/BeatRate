import Composition
import FirebaseService
import FirebaseServiceFakes
import Foundation
import Models
import SplashUseCases
import Testing
@testable import BeatRateFixtures

struct EdgesFixturesTests {
    @Test func `the device section seeds keychain, login row, firebase session and defaults`() async throws {
        let graph = Graph(edges: try await .fixtures(try fixtures(Sample.signedIn)))

        #expect(await graph.getSplash.isUserLoggedIn())
        #expect(await graph.getSplash.areCredentialsValid())
        #expect(graph.analytics.consent == true)
        #expect(await graph.getSplash.hydrateMainMusicPlayer())
        #expect(graph.players.current == .appleMusic)
    }

    @Test func `an empty fixture is a fresh guest install`() async throws {
        let graph = Graph(edges: try await .fixtures(try fixtures("{}")))

        #expect(await graph.getSplash.isUserLoggedIn() == false)
        #expect(graph.analytics.consent == nil)
        #expect(graph.retryDelay == .zero)
    }

    @Test(arguments: [("authorized", true), ("revoked", false), ("notFound", false), ("transferred", false)])
    func `the apple id state comes from the fixture`(state: String, isValid: Bool) async throws {
        let graph = Graph(edges: try await .fixtures(try fixtures(Sample.signedIn, #"{"device":{"appleIDState":"\#(state)"}}"#)))

        #expect(await graph.getSplash.areCredentialsValid() == isValid)
    }

    @Test func `the retry delay comes from the timing section`() async throws {
        let edges = try await Edges.fixtures(try fixtures(#"{"timing":{"retryDelayMs":300}}"#))

        #expect(edges.retryDelay == .milliseconds(300))
    }

    @Test func `music access starts undecided and the request answers from the fixture`() async throws {
        let edges = try await Edges.fixtures(try fixtures(#"{"music":{"authorization":"notDetermined","answer":"denied"}}"#))

        #expect(await edges.musicKit.isAuthorizationDetermined() == false)
        #expect(await edges.musicKit.requestMusicAuthorization().status == .denied)
        #expect(await edges.musicKit.isAuthorizationDetermined())
        #expect(await edges.musicKit.isAuthorized() == false)
    }

    @Test func `an authorized fixture grants access with the subscription it names`() async throws {
        let edges = try await Edges.fixtures(try fixtures(#"{"music":{"subscription":true}}"#))

        let result = await edges.musicKit.requestMusicAuthorization()
        #expect(result.status == .authorized)
        #expect(result.hasSubscription)
        #expect(await edges.musicKit.isAuthorized())
    }

    @Test func `an album in the music section is returned`() async throws {
        let edges = try await Edges.fixtures(try fixtures(#"{"music":{"albums":{"1440935467":\#(Sample.discoveryAlbum)}}}"#))

        let album = try await edges.musicKit.fetchAlbumData(by: "1440935467")
        #expect(album?.title == "Discovery")
        #expect(album?.artist == "Daft Punk")
    }

    @Test func `album data is refused while music access is not authorized`() async throws {
        let edges = try await Edges.fixtures(try fixtures(
            #"{"music":{"authorization":"denied","albums":{"1440935467":\#(Sample.discoveryAlbum)}}}"#))

        await #expect(throws: FakeMusicKitError.notAuthorized) { try await edges.musicKit.fetchAlbumData(by: "1440935467") }
    }

    @Test func `the db section is the tree the service reads`() async throws {
        let edges = try await Edges.fixtures(try fixtures(#"{"db":{"albums":{"1":{"title":"Discovery"}}}}"#))

        let node = try await edges.database.read("albums/1/title")
        #expect(node.raw as? String == "Discovery")
    }

    @Test func `failing db paths throw and the delay holds each call back`() async throws {
        let edges = try await Edges.fixtures(try fixtures(
            #"{"dbFailures":{"reads":["sections"],"writes":["albums/1"]},"dbDelayMs":50}"#))
        let clock = ContinuousClock()

        let start = clock.now
        await #expect(throws: FakeDatabaseError(path: "sections")) { try await edges.database.read("sections") }
        #expect(clock.now - start >= .milliseconds(50))
        await #expect(throws: FakeDatabaseError(path: "albums/1")) {
            try await edges.database.write(DatabaseValue("x"), to: "albums/1")
        }
    }
}
