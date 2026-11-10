import Foundation
import Testing
@testable import SpotifyService

struct SpotifySessionFailureTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func session(_ store: StubTokenStore, scripted: [StubTransport.Scripted] = []) -> SpotifySession {
        SpotifySession(tokenStore: store, transport: StubTransport(scripted: scripted), clientId: "cid")
    }

    private var staleTokens: SpotifyTokens {
        SpotifyTokens(accessToken: "old", refreshToken: "r", expiresAt: now.addingTimeInterval(-1))
    }

    @Test func `forced refresh without a session reports no session`() async {
        await #expect(throws: SpotifyFailure.noSession) { try await session(StubTokenStore()).refreshedAccessToken(at: now) }
    }

    @Test func `unreadable keychain reads as no session`() async {
        await #expect(throws: SpotifyFailure.noSession) { try await session(StubTokenStore(failsToLoad: true)).validAccessToken(at: now) }
    }

    @Test func `stale token without a refresh token ends the session`() async {
        let store = StubTokenStore(tokens: SpotifyTokens(accessToken: "old", refreshToken: nil, expiresAt: now.addingTimeInterval(-1)))

        await #expect(throws: SpotifyFailure.sessionExpired) { try await session(store).validAccessToken(at: now) }
        #expect(await store.clearCount == 1)
    }

    @Test func `token endpoint outage keeps the tokens`() async {
        let store = StubTokenStore(tokens: staleTokens)

        await #expect(throws: SpotifyFailure.transient) {
            try await session(store, scripted: [.init(status: 503)]).validAccessToken(at: now)
        }
        #expect(await store.clearCount == 0)
    }

    @Test func `garbled token response keeps the tokens`() async {
        let store = StubTokenStore(tokens: staleTokens)

        await #expect(throws: SpotifyFailure.transient) {
            try await session(store, scripted: [.init(status: 200, body: Data("not json".utf8))]).validAccessToken(at: now)
        }
        #expect(await store.clearCount == 0)
    }

    @Test func `authorize url carries the pkce challenge, redirect and scopes`() async throws {
        let url = await session(StubTokenStore()).authorizationURL(codeChallenge: "challenge", redirectUri: URL(string: "beatrate://spotify-callback")!)

        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
        #expect(url.host() == "accounts.spotify.com")
        #expect(query["client_id"] == "cid")
        #expect(query["response_type"] == "code")
        #expect(query["redirect_uri"] == "beatrate://spotify-callback")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["code_challenge"] == "challenge")
        #expect(query["scope"] == SpotifyAPI.scopes)
    }

    @Test func `refresh without a new lifetime falls back to the default`() {
        let response = SpotifyTokenResponse(accessToken: "new", refreshToken: nil, expiresIn: nil)

        let merged = staleTokens.merging(response, issuedAt: now)

        #expect(merged.expiresAt == now.addingTimeInterval(SpotifyTokenResponse.defaultLifetime))
        #expect(merged.refreshToken == "r")
    }

    @Test func `clearing the token store deletes the keychain item`() async throws {
        let keychain = StubKeychain(tokenData: Data("{}".utf8))

        try await SpotifyTokenStore(keychain: keychain).clear()

        #expect(await keychain.savedTokenData() == nil)
    }
}
