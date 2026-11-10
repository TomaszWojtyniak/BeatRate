import Foundation
import Testing
@testable import SpotifyService

@MainActor
struct SpotifyServiceConnectionTests {

    private static let fresh = SpotifyTokens(accessToken: "token", refreshToken: "r", expiresAt: .distantFuture)

    private func service(tokens: SpotifyTokens? = fresh, scripted: [StubTransport.Scripted]) -> (SpotifyService, StubTokenStore) {
        let store = StubTokenStore(tokens: tokens)
        let transport = StubTransport(scripted: scripted)
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")
        return (SpotifyService(session: session, client: SpotifyClient(transport: transport, retryDelay: { _ in })), store)
    }

    @Test(arguments: [
        (#"{"product":"premium"}"#, SpotifyPremiumStatus.premium),
        (#"{"product":"free"}"#, .free),
        ("{}", .unknown),
    ])
    func `working session is connected with its premium status`(body: String, premium: SpotifyPremiumStatus) async {
        let (service, _) = service(scripted: [.init(status: 200, body: Data(body.utf8))])

        #expect(await service.verifyConnection() == .connected(premium: premium))
    }

    @Test func `no stored tokens means never connected`() async {
        let (service, _) = service(tokens: nil, scripted: [])

        #expect(await service.verifyConnection() == .notConnected)
        #expect(await !service.hasStoredSession())
    }

    @Test func `stored tokens count as a session`() async {
        #expect(await service(scripted: []).0.hasStoredSession())
    }

    @Test func `rejected refresh after a 401 needs reauthorization`() async {
        let (service, _) = service(scripted: [.init(status: 401), .init(status: 400)])

        #expect(await service.verifyConnection() == .needsReauth)
    }

    @Test func `forbidden account is not on the allowlist`() async {
        let (service, _) = service(scripted: [.init(status: 403)])

        #expect(await service.verifyConnection() == .notAllowlisted)
    }

    // A dropped connection at launch used to force a full reconnect.
    @Test func `server trouble leaves the session alone`() async {
        let (service, store) = service(scripted: [.init(status: 500), .init(status: 500), .init(status: 500)])

        #expect(await service.verifyConnection() == .unavailable)
        #expect(await store.clearCount == 0)
    }

    @Test func `recently played albums are deduplicated in listening order`() async throws {
        let body = #"""
        {"items":[
          {"track":{"album":{"id":"a","name":"Blonde","artists":[{"name":"Frank Ocean"}]}}},
          {"track":{"album":{"id":"b","name":"Untitled","artists":[]}}},
          {"track":{"album":{"id":"a","name":"Blonde","artists":[{"name":"Frank Ocean"}]}}}
        ]}
        """#
        let (service, _) = service(scripted: [.init(status: 200, body: Data(body.utf8))])

        let albums = try await service.fetchRecentlyPlayedAlbums()

        #expect(albums == [
            SpotifyRecentAlbum(id: "a", name: "Blonde", artist: "Frank Ocean"),
            SpotifyRecentAlbum(id: "b", name: "Untitled", artist: ""),
        ])
    }

    @Test func `undecodable response is transient`() async {
        let (service, _) = service(scripted: [.init(status: 200, body: Data("[]".utf8))])

        await #expect(throws: SpotifyFailure.transient) { try await service.fetchRecentlyPlayedAlbums() }
    }

    @Test func `connecting without a redirect uri fails before any request`() async {
        let (service, _) = service(scripted: [])

        await #expect(throws: SpotifyFailure.authorizationFailed) { try await service.requestAuthorization() }
    }
}
