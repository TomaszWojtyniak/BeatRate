//
//  SpotifySession.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation
import Analytics
import OSLog

/// Owns the Spotify token lifecycle and nothing else: authorization, storage,
/// expiry, refresh. Endpoint knowledge lives in `SpotifyClient`.
actor SpotifySession {
    private let tokenStore: any SpotifyTokenStoring
    private let transport: any SpotifyTransport
    private let clientId: String
    private let redirectUri: URL?
    private let callbackScheme: String?

    /// In-flight refresh shared by concurrent callers. Spotify rotates refresh
    /// tokens, so two parallel refreshes would invalidate each other.
    private var refreshTask: Task<SpotifyTokens, Error>?

    init(
        tokenStore: any SpotifyTokenStoring,
        transport: any SpotifyTransport,
        clientId: String,
        redirectUri: URL? = nil,
        callbackScheme: String? = nil
    ) {
        self.tokenStore = tokenStore
        self.transport = transport
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.callbackScheme = callbackScheme
    }

    // MARK: - Authorization

    func authorize() async throws -> SpotifyTokens {
        guard let redirectUri, let callbackScheme else {
            throw SpotifyFailure.authorizationFailed
        }

        let pkce = PKCE()
        let webAuth = await SpotifyWebAuthSession()
        let code = try await webAuth.authorize(
            url: authorizationURL(codeChallenge: pkce.challenge, redirectUri: redirectUri),
            callbackScheme: callbackScheme
        )

        let response = try await postToken(fields: [
            (SpotifyAPI.Param.grantType, SpotifyAPI.GrantType.authorizationCode),
            (SpotifyAPI.Param.code, code),
            (SpotifyAPI.Param.redirectUri, redirectUri.absoluteString),
            (SpotifyAPI.Param.clientId, clientId),
            (SpotifyAPI.Param.codeVerifier, pkce.verifier)
        ])

        let tokens = response.tokens()
        try await tokenStore.save(tokens)
        Logger.spotifyService.info("Spotify authorization successful")
        return tokens
    }

    // MARK: - Token Access

    /// Returns a usable access token, refreshing proactively when the stored one
    /// is inside its leeway. Avoids the guaranteed 401 round-trip the old code
    /// paid on the first request after every expiry.
    func validAccessToken(at now: Date = Date()) async throws -> String {
        guard let tokens = try await loadTokens() else { throw SpotifyFailure.noSession }
        if tokens.isFresh(at: now) { return tokens.accessToken }
        return try await refresh(from: tokens, at: now).accessToken
    }

    /// Forces a refresh regardless of expiry. Used after a 401 on a token we
    /// believed was fresh.
    func refreshedAccessToken(at now: Date = Date()) async throws -> String {
        guard let tokens = try await loadTokens() else { throw SpotifyFailure.noSession }
        return try await refresh(from: tokens, at: now).accessToken
    }

    func hasStoredSession() async -> Bool {
        ((try? await tokenStore.load()) ?? nil) != nil
    }

    func signOut() async {
        refreshTask = nil
        try? await tokenStore.clear()
        Logger.spotifyService.info("Spotify session cleared")
    }

    // MARK: - Refresh

    private func loadTokens() async throws -> SpotifyTokens? {
        do {
            return try await tokenStore.load()
        } catch {
            Logger.spotifyService.error("Failed to read Spotify tokens: \(error)")
            throw SpotifyFailure.noSession
        }
    }

    /// `refreshTask` is assigned with no suspension between the nil-check and the
    /// store, so concurrent callers join the same refresh rather than racing.
    private func refresh(from tokens: SpotifyTokens, at now: Date) async throws -> SpotifyTokens {
        if let refreshTask { return try await refreshTask.value }

        let task = Task { try await performRefresh(from: tokens, at: now) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh(from tokens: SpotifyTokens, at now: Date) async throws -> SpotifyTokens {
        guard let refreshToken = tokens.refreshToken else {
            Logger.spotifyService.error("No refresh token on file — session expired")
            await signOut()
            throw SpotifyFailure.sessionExpired
        }

        let response = try await postToken(fields: [
            (SpotifyAPI.Param.grantType, SpotifyAPI.GrantType.refreshToken),
            (SpotifyAPI.Param.refreshToken, refreshToken),
            (SpotifyAPI.Param.clientId, clientId)
        ])

        let refreshed = tokens.merging(response, issuedAt: now)
        try await tokenStore.save(refreshed)
        Logger.spotifyService.info("Spotify token refresh successful")
        return refreshed
    }

    // MARK: - Token Endpoint

    /// The critical distinction: Spotify rejecting the grant kills the session,
    /// but a network failure must leave the tokens untouched. Conflating these
    /// is what signed users out whenever their connection blipped.
    private func postToken(fields: [(name: String, value: String)]) async throws -> SpotifyTokenResponse {
        var request = URLRequest(url: SpotifyAPI.token)
        request.httpMethod = HTTP.Method.post
        request.setValue(HTTP.HeaderValue.formURLEncoded, forHTTPHeaderField: HTTP.Header.contentType)
        request.httpBody = SpotifyNetworkClient.formEncode(fields)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            Logger.spotifyService.error("Spotify token request failed in transport: \(error)")
            throw SpotifyResponseClassifier.failure(forTransportError: error)
        }

        guard (200...299).contains(response.statusCode) else {
            Logger.spotifyService.error("Spotify token request rejected: \(response.statusCode)")
            if (400...499).contains(response.statusCode) {
                await signOut()
                throw SpotifyFailure.sessionExpired
            }
            throw SpotifyFailure.transient
        }

        do {
            return try SpotifyNetworkClient().decode(data)
        } catch {
            Logger.spotifyService.error("Spotify token response failed to decode: \(error)")
            throw SpotifyFailure.transient
        }
    }

    private func authorizationURL(codeChallenge: String, redirectUri: URL) -> URL {
        SpotifyAPI.authorize.appending(queryItems: [
            URLQueryItem(name: SpotifyAPI.Param.clientId, value: clientId),
            URLQueryItem(name: SpotifyAPI.Param.responseType, value: SpotifyAPI.Value.responseTypeCode),
            URLQueryItem(name: SpotifyAPI.Param.redirectUri, value: redirectUri.absoluteString),
            URLQueryItem(name: SpotifyAPI.Param.codeChallengeMethod, value: SpotifyAPI.Value.challengeMethodS256),
            URLQueryItem(name: SpotifyAPI.Param.codeChallenge, value: codeChallenge),
            URLQueryItem(name: SpotifyAPI.Param.scope, value: SpotifyAPI.scopes)
        ])
    }
}
