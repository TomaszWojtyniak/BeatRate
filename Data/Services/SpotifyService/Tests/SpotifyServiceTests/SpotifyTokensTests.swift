import Foundation
import Testing
@testable import SpotifyService

struct SpotifyTokensTests {
    private let client = SpotifyNetworkClient()
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func tokenIsFreshWhenComfortablyBeforeExpiry() {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(600))
        #expect(tokens.isFresh(at: now))
    }

    @Test func tokenIsStaleInsideTheRefreshLeeway() {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(30))
        #expect(!tokens.isFresh(at: now))
    }

    @Test func expiredTokenIsStale() {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(-1))
        #expect(!tokens.isFresh(at: now))
    }

    @Test func responseDecodesExpiresInAndProjectsExpiry() throws {
        let json = Data(#"{"access_token": "abc", "refresh_token": "def", "expires_in": 3600}"#.utf8)
        let response: SpotifyTokenResponse = try client.decode(json)
        #expect(response.expiresIn == 3600)

        let tokens = response.tokens(issuedAt: now)
        #expect(tokens.accessToken == "abc")
        #expect(tokens.refreshToken == "def")
        #expect(tokens.expiresAt == now.addingTimeInterval(3600))
    }

    @Test func missingExpiresInFallsBackToDefaultLifetime() throws {
        let json = Data(#"{"access_token": "abc"}"#.utf8)
        let response: SpotifyTokenResponse = try client.decode(json)
        let tokens = response.tokens(issuedAt: now)
        #expect(tokens.expiresAt == now.addingTimeInterval(SpotifyTokenResponse.defaultLifetime))
    }

    @Test func tokensRoundTripThroughJSON() throws {
        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now)
        let restored = try SpotifyTokens.decoded(from: tokens.encoded())
        #expect(restored == tokens)
    }
}
