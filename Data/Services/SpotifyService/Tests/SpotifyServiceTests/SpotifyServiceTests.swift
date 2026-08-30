import Foundation
import Testing
@testable import SpotifyService

// MARK: - PKCE

struct PKCETests {
    @Test func challengeMatchesRFC7636TestVector() {
        // RFC 7636 Appendix B
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func generatedPairUsesBase64URLAlphabet() {
        let pkce = PKCE()
        #expect(!pkce.verifier.isEmpty)
        #expect(!pkce.verifier.contains("+"))
        #expect(!pkce.verifier.contains("/"))
        #expect(!pkce.verifier.contains("="))
        #expect(pkce.challenge == PKCE.challenge(for: pkce.verifier))
    }

    @Test func base64URLEncodingReplacesReservedCharacters() {
        // 0xFF 0xEF is "/+8=" in standard base64
        #expect(PKCE.base64URLEncode(Data([0xFF, 0xEF])) == "_-8")
    }
}

// MARK: - Response Decoding

struct ResponseDecodingTests {
    private let client = SpotifyNetworkClient()

    @Test func tokenResponseDecodesSnakeCaseKeys() throws {
        let json = Data(#"{"access_token": "abc", "refresh_token": "def"}"#.utf8)
        let response: SpotifyTokenResponse = try client.decode(json)
        #expect(response.accessToken == "abc")
        #expect(response.refreshToken == "def")
    }

    @Test func tokenResponseAllowsMissingRefreshToken() throws {
        let json = Data(#"{"access_token": "abc"}"#.utf8)
        let response: SpotifyTokenResponse = try client.decode(json)
        #expect(response.refreshToken == nil)
    }

    @Test func recentlyPlayedDeduplicatesAlbumsPreservingOrder() throws {
        let json = Data("""
        {
            "items": [
                {"track": {"album": {"id": "a1", "name": "First", "artists": [{"name": "Artist A"}]}}},
                {"track": {"album": {"id": "a2", "name": "Second", "artists": [{"name": "Artist B"}]}}},
                {"track": {"album": {"id": "a1", "name": "First", "artists": [{"name": "Artist A"}]}}}
            ]
        }
        """.utf8)
        let response: SpotifyRecentlyPlayedResponse = try client.decode(json)
        #expect(response.uniqueAlbums == [
            SpotifyRecentAlbum(id: "a1", name: "First", artist: "Artist A"),
            SpotifyRecentAlbum(id: "a2", name: "Second", artist: "Artist B")
        ])
    }
}

// MARK: - Search URL

struct SpotifyAPITests {
    @Test func recentlyPlayedURLCarriesLimit() throws {
        let url = SpotifyAPI.recentlyPlayed(limit: SpotifyAPI.Limit.recentlyPlayedPage)
        let queryItems = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.path().hasSuffix("me/player/recently-played"))
        #expect(queryItems.first { $0.name == SpotifyAPI.Param.limit }?.value == "50")
    }
}
