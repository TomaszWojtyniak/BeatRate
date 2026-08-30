//
//  SpotifyAPI.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

/// Catalog of every Spotify Web API endpoint, parameter name, fixed value, and
/// page limit the service uses. Force-unwraps of known-valid URL literals live
/// only in this file.
nonisolated enum SpotifyAPI {

    // MARK: - Endpoints

    static let authorize = URL(string: "https://accounts.spotify.com/authorize")!
    static let token = URL(string: "https://accounts.spotify.com/api/token")!

    private static let base = URL(string: "https://api.spotify.com/v1")!

    static let me = base.appending(path: "me")

    static func recentlyPlayed(limit: Int) -> URL {
        me.appending(path: "player/recently-played")
            .appending(queryItems: [
                URLQueryItem(name: Param.limit, value: String(limit))
            ])
    }

    // MARK: - OAuth

    static let scopes = "user-read-private user-read-recently-played"

    // MARK: - Query / Form Parameter Names

    enum Param {
        static let clientId = "client_id"
        static let responseType = "response_type"
        static let redirectUri = "redirect_uri"
        static let codeChallengeMethod = "code_challenge_method"
        static let codeChallenge = "code_challenge"
        static let scope = "scope"
        static let grantType = "grant_type"
        static let code = "code"
        static let codeVerifier = "code_verifier"
        static let refreshToken = "refresh_token"
        static let limit = "limit"
    }

    enum GrantType {
        static let authorizationCode = "authorization_code"
        static let refreshToken = "refresh_token"
    }

    // MARK: - Fixed Values

    enum Value {
        static let responseTypeCode = "code"
        static let challengeMethodS256 = "S256"
        static let premiumProduct = "premium"
    }

    // MARK: - Page Limits

    enum Limit {
        /// Full page used when resolving albums from listening history.
        static let recentlyPlayedPage = 50
    }
}
