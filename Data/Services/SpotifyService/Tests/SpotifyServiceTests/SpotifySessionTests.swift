import Foundation
import Testing
@testable import SpotifyService

struct SpotifySessionTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func freshTokens(_ offset: TimeInterval = 600) -> SpotifyTokens {
        SpotifyTokens(accessToken: "fresh", refreshToken: "r1", expiresAt: now.addingTimeInterval(offset))
    }

    private func refreshBody(accessToken: String, refreshToken: String? = nil) -> Data {
        var json = #"{"access_token": "\#(accessToken)", "expires_in": 3600"#
        if let refreshToken {
            json += #", "refresh_token": "\#(refreshToken)""#
        }
        json += "}"
        return Data(json.utf8)
    }

    @Test func freshTokenIsReturnedWithoutHittingTheNetwork() async throws {
        let store = StubTokenStore(tokens: freshTokens())
        let transport = StubTransport()
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        let token = try await session.validAccessToken(at: now)

        #expect(token == "fresh")
        #expect(await transport.sentCount == 0)
    }

    @Test func staleTokenTriggersRefresh() async throws {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 200, body: refreshBody(accessToken: "renewed", refreshToken: "r2"))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        let token = try await session.validAccessToken(at: now)

        #expect(token == "renewed")
        #expect(await store.currentTokens()?.refreshToken == "r2")
    }

    @Test func refreshCarriesForwardRefreshTokenWhenSpotifyOmitsIt() async throws {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 200, body: refreshBody(accessToken: "renewed"))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        _ = try await session.validAccessToken(at: now)

        #expect(await store.currentTokens()?.refreshToken == "r1")
    }

    @Test func missingTokensThrowNoSession() async {
        let session = SpotifySession(
            tokenStore: StubTokenStore(tokens: nil),
            transport: StubTransport(),
            clientId: "cid"
        )

        await #expect(throws: SpotifyFailure.noSession) {
            _ = try await session.validAccessToken(at: now)
        }
    }

    @Test func rejectedRefreshExpiresSessionAndClearsStore() async {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 400, body: Data(#"{"error":"invalid_grant"}"#.utf8))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        await #expect(throws: SpotifyFailure.sessionExpired) {
            _ = try await session.validAccessToken(at: now)
        }
        #expect(await store.clearCount == 1)
    }

    @Test func offlineRefreshIsTransientAndKeepsTokens() async {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(transportError: URLError(.notConnectedToInternet))
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        await #expect(throws: SpotifyFailure.transient) {
            _ = try await session.validAccessToken(at: now)
        }
        // The headline bug: a network blip must never sign the user out.
        #expect(await store.clearCount == 0)
        #expect(await store.currentTokens() != nil)
    }

    @Test func concurrentRefreshesCoalesceIntoOneNetworkCall() async throws {
        let store = StubTokenStore(tokens: freshTokens(10))
        let transport = StubTransport(scripted: [
            .init(status: 200, body: refreshBody(accessToken: "renewed", refreshToken: "r2"))
        ])
        let session = SpotifySession(tokenStore: store, transport: transport, clientId: "cid")

        async let first = session.validAccessToken(at: now)
        async let second = session.validAccessToken(at: now)
        async let third = session.validAccessToken(at: now)
        let tokens = try await [first, second, third]

        #expect(tokens == ["renewed", "renewed", "renewed"])
        #expect(await transport.sentCount == 1)
    }

    @Test func hasStoredSessionReflectsTheStoreWithoutNetwork() async {
        let empty = SpotifySession(tokenStore: StubTokenStore(tokens: nil), transport: StubTransport(), clientId: "cid")
        let populated = SpotifySession(tokenStore: StubTokenStore(tokens: freshTokens()), transport: StubTransport(), clientId: "cid")

        #expect(await empty.hasStoredSession() == false)
        #expect(await populated.hasStoredSession() == true)
    }
}
