import Foundation
import Testing
@testable import SpotifyService

struct SpotifyClientTests {

    private func session(_ transport: StubTransport) -> SpotifySession {
        SpotifySession(
            tokenStore: StubTokenStore(tokens: SpotifyTokens(
                accessToken: "tok", refreshToken: "r1", expiresAt: .distantFuture
            )),
            transport: transport,
            clientId: "cid"
        )
    }

    private let userBody = Data(#"{"product": "premium"}"#.utf8)

    @Test func successfulRequestDecodes() async throws {
        let transport = StubTransport(scripted: [.init(status: 200, body: userBody)])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))

        #expect(user.product == "premium")
    }

    @Test func forbiddenIsNotAllowlistedAndIsNotRetried() async {
        let transport = StubTransport(scripted: [.init(status: 403)])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.notAllowlisted) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 1)
    }

    @Test func rateLimitRetriesThenGivesUpWithRetryAfter() async {
        let transport = StubTransport(scripted: [
            .init(status: 429, headers: ["Retry-After": "1"]),
            .init(status: 429, headers: ["Retry-After": "1"]),
            .init(status: 429, headers: ["Retry-After": "3"])
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.rateLimited(retryAfter: 3)) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 3)
    }

    @Test func rateLimitRecoversOnRetry() async throws {
        let transport = StubTransport(scripted: [
            .init(status: 429, headers: ["Retry-After": "1"]),
            .init(status: 200, body: userBody)
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))

        #expect(user.product == "premium")
        #expect(await transport.sentCount == 2)
    }

    @Test func serverErrorRetriesThenBecomesTransient() async {
        let transport = StubTransport(scripted: [
            .init(status: 503), .init(status: 503), .init(status: 503)
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.transient) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 3)
    }

    @Test func offlineIsTransientAndNotRetried() async {
        let transport = StubTransport(transportError: URLError(.notConnectedToInternet))
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.transient) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
        #expect(await transport.sentCount == 1)
    }

    @Test func unauthorizedRefreshesOnceThenSucceeds() async throws {
        let refreshBody = Data(#"{"access_token": "renewed", "expires_in": 3600}"#.utf8)
        let transport = StubTransport(scripted: [
            .init(status: 401),                     // original request
            .init(status: 200, body: refreshBody),  // token refresh
            .init(status: 200, body: userBody)      // retried request
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))

        #expect(user.product == "premium")
        #expect(await transport.sentCount == 3)
        #expect(await transport.authorizationHeaders().last == "Bearer renewed")
    }

    @Test func persistentUnauthorizedEndsAsSessionExpired() async {
        let refreshBody = Data(#"{"access_token": "renewed", "expires_in": 3600}"#.utf8)
        let transport = StubTransport(scripted: [
            .init(status: 401),
            .init(status: 200, body: refreshBody),
            .init(status: 401)
        ])
        let client = SpotifyClient(transport: transport, retryDelay: { _ in })

        await #expect(throws: SpotifyFailure.sessionExpired) {
            let _: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session(transport))
        }
    }
}
