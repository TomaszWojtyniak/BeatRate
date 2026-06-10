//
//  SpotifyService.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 04/03/2026.
//

import Foundation
import CoreApp
import Analytics
import OSLog

public actor SpotifyService: SpotifyServiceProtocol {
    public static let shared = SpotifyService()

    private let clientId: String
    private let redirectUri: URL
    private let callbackScheme: String
    private let network = SpotifyNetworkClient()
    private let tokenStore: SpotifyTokenStore
    /// In-flight refresh shared by concurrent callers — see `refreshAccessToken()`.
    private var refreshTask: Task<String, Error>?

    public init(
        clientId: String = AppEnvironment.current.spotifyClientId,
        redirectUri: String = AppEnvironment.current.spotifyRedirectUri,
        keychainManager: KeychainManager = .shared
    ) {
        guard let url = URL(string: redirectUri), let scheme = url.scheme else {
            preconditionFailure("Invalid Spotify redirect URI: \(redirectUri)")
        }
        self.clientId = clientId
        self.redirectUri = url
        self.callbackScheme = scheme
        self.tokenStore = SpotifyTokenStore(keychain: keychainManager)
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws -> SpotifyAuthResult {
        Logger.spotifyService.info("Starting Spotify authorization")

        let pkce = PKCE()
        let webAuth = await SpotifyWebAuthSession()
        let code = try await webAuth.authorize(
            url: authorizationURL(codeChallenge: pkce.challenge),
            callbackScheme: callbackScheme
        )

        let tokenResponse = try await exchangeCodeForToken(code: code, codeVerifier: pkce.verifier)
        try await tokenStore.persist(tokenResponse)

        let isPremium = await checkPremiumStatus(accessToken: tokenResponse.accessToken)

        Logger.spotifyService.info("Spotify authorization successful, premium: \(isPremium)")
        return SpotifyAuthResult(isAuthorized: true, hasSpotifyPremium: isPremium)
    }

    // MARK: - Connection State

    public func hasAccessToken() async -> Bool {
        (try? await tokenStore.accessToken()) != nil
    }

    /// Pings `/me` with the saved access token, transparently refreshing on 401.
    /// Distinguishes "no token at all" from "token can't be revived" so the caller
    /// can choose whether to prompt for re-auth.
    public func verifyConnection() async -> SpotifyConnectionState {
        do {
            _ = try await authorizedData(from: SpotifyAPI.me)
            return .connected
        } catch SpotifyError.missingAccessToken {
            return .notConnected
        } catch {
            Logger.spotifyService.error("Spotify connection verify failed: \(error)")
            return .invalid
        }
    }

    // MARK: - Recently Played

    public func fetchRecentlyPlayed() async throws {
        _ = try await authorizedData(
            from: SpotifyAPI.recentlyPlayed(limit: SpotifyAPI.Limit.recentlyPlayedProbe)
        )
    }

    public func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum] {
        let response: SpotifyRecentlyPlayedResponse = try await authorized(
            from: SpotifyAPI.recentlyPlayed(limit: SpotifyAPI.Limit.recentlyPlayedPage)
        )
        let albums = response.uniqueAlbums
        Logger.spotifyService.info("Resolved \(albums.count) recently-played Spotify albums")
        return albums
    }

    // MARK: - Album Search

    public func searchAlbumId(name: String, artist: String) async -> String? {
        do {
            let response: SpotifySearchResponse = try await authorized(
                from: SpotifyAPI.searchAlbum(name: name, artist: artist)
            )
            let id = response.albums?.items.first?.id
            Logger.spotifyService.info("Spotify search resolved album id: \(id ?? "nil")")
            return id
        } catch SpotifyError.missingAccessToken {
            Logger.spotifyService.info("Album search skipped — no Spotify access token")
            return nil
        } catch {
            Logger.spotifyService.error("Spotify search failed: \(error)")
            return nil
        }
    }

    // MARK: - Authorized Requests

    /// Single entry point for bearer-authenticated GETs: loads the stored token,
    /// refreshes it once on a 401, and validates the final status code.
    private func authorizedData(from url: URL) async throws -> Data {
        guard let accessToken = try await tokenStore.accessToken() else {
            Logger.spotifyService.error("No Spotify access token found")
            throw SpotifyError.missingAccessToken
        }

        var (data, statusCode) = try await network.get(url, accessToken: accessToken)

        if statusCode == HTTP.Status.unauthorized {
            Logger.spotifyService.info("Access token expired, attempting refresh")
            let refreshedToken = try await refreshAccessToken()
            (data, statusCode) = try await network.get(url, accessToken: refreshedToken)
        }

        guard statusCode == HTTP.Status.ok else {
            Logger.spotifyService.error("Spotify request failed with status \(statusCode): \(url.path)")
            throw SpotifyError.requestFailed(statusCode: statusCode)
        }

        return data
    }

    private func authorized<T: Decodable>(from url: URL) async throws -> T {
        try network.decode(try await authorizedData(from: url))
    }

    // MARK: - Token Refresh

    /// Coalesces concurrent refreshes: Spotify rotates refresh tokens, so two
    /// parallel refresh calls would invalidate each other's sessions.
    private func refreshAccessToken() async throws -> String {
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await performTokenRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performTokenRefresh() async throws -> String {
        guard let refreshToken = try await tokenStore.refreshToken() else {
            Logger.spotifyService.error("No refresh token available")
            throw SpotifyError.refreshTokenMissing
        }

        do {
            let tokenResponse: SpotifyTokenResponse = try await network.postForm(
                SpotifyAPI.token,
                fields: [
                    (SpotifyAPI.Param.grantType, SpotifyAPI.GrantType.refreshToken),
                    (SpotifyAPI.Param.refreshToken, refreshToken),
                    (SpotifyAPI.Param.clientId, clientId)
                ]
            )
            try await tokenStore.persist(tokenResponse)
            Logger.spotifyService.info("Token refresh successful")
            return tokenResponse.accessToken
        } catch {
            Logger.spotifyService.error("Token refresh failed: \(error)")
            throw SpotifyError.tokenRefreshFailed
        }
    }

    // MARK: - Auth Flow Helpers

    private func authorizationURL(codeChallenge: String) -> URL {
        SpotifyAPI.authorize.appending(queryItems: [
            URLQueryItem(name: SpotifyAPI.Param.clientId, value: clientId),
            URLQueryItem(name: SpotifyAPI.Param.responseType, value: SpotifyAPI.Value.responseTypeCode),
            URLQueryItem(name: SpotifyAPI.Param.redirectUri, value: redirectUri.absoluteString),
            URLQueryItem(name: SpotifyAPI.Param.codeChallengeMethod, value: SpotifyAPI.Value.challengeMethodS256),
            URLQueryItem(name: SpotifyAPI.Param.codeChallenge, value: codeChallenge),
            URLQueryItem(name: SpotifyAPI.Param.scope, value: SpotifyAPI.scopes)
        ])
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> SpotifyTokenResponse {
        do {
            return try await network.postForm(
                SpotifyAPI.token,
                fields: [
                    (SpotifyAPI.Param.grantType, SpotifyAPI.GrantType.authorizationCode),
                    (SpotifyAPI.Param.code, code),
                    (SpotifyAPI.Param.redirectUri, redirectUri.absoluteString),
                    (SpotifyAPI.Param.clientId, clientId),
                    (SpotifyAPI.Param.codeVerifier, codeVerifier)
                ]
            )
        } catch {
            Logger.spotifyService.error("Token exchange failed: \(error)")
            throw SpotifyError.tokenExchangeFailed
        }
    }

    private func checkPremiumStatus(accessToken: String) async -> Bool {
        do {
            let (data, _) = try await network.get(SpotifyAPI.me, accessToken: accessToken)
            let user: SpotifyUserResponse = try network.decode(data)
            return user.product == SpotifyAPI.Value.premiumProduct
        } catch {
            Logger.spotifyService.error("Premium check failed: \(error)")
            return false
        }
    }
}
