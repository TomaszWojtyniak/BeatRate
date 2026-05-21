//
//  SpotifyService.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 04/03/2026.
//

import Foundation
import Models
import CoreApp
import Analytics
import OSLog
import AuthenticationServices
import CryptoKit

// MARK: - Protocol

public enum SpotifyConnectionState: Sendable {
    /// A valid token is on file (verified against `/me`).
    case connected
    /// No access token in the Keychain.
    case notConnected
    /// We had a token but Spotify rejected it and refresh failed — the user must re-auth.
    case invalid
}

public protocol SpotifyServiceProtocol: Sendable {
    func requestAuthorization() async throws -> SpotifyAuthResult
    func fetchRecentlyPlayed() async throws
    func hasAccessToken() async -> Bool
    func searchAlbumId(name: String, artist: String) async -> String?
    func verifyConnection() async -> SpotifyConnectionState
}

// MARK: - Spotify API

private nonisolated enum SpotifyAPI {
    static let authURL = "https://accounts.spotify.com/authorize"
    static let tokenURL = "https://accounts.spotify.com/api/token"
    static let baseURL = "https://api.spotify.com/v1"
    static let meURL = "\(baseURL)/me"
    static let recentlyPlayedURL = "\(baseURL)/me/player/recently-played"
    static let searchURL = "\(baseURL)/search"

    static let scopes = "user-read-private user-read-recently-played"

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
    }
}

// MARK: - SpotifyService

public actor SpotifyService: SpotifyServiceProtocol {
    public static let shared = SpotifyService()

    private let clientId: String
    private let redirectUri: URL
    private let keychainManager: KeychainManager

    public init(
        clientId: String = AppEnvironment.current.spotifyClientId,
        redirectUri: String = AppEnvironment.current.spotifyRedirectUri,
        keychainManager: KeychainManager = .shared
    ) {
        self.clientId = clientId
        self.redirectUri = URL(string: redirectUri)!
        self.keychainManager = keychainManager
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws -> SpotifyAuthResult {
        Logger.spotifyService.info("Starting Spotify authorization")

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        let code = try await startAuthSession(codeChallenge: codeChallenge)
        let tokenResponse = try await exchangeCodeForToken(code: code, codeVerifier: codeVerifier)

        try await keychainManager.saveSpotifyAccessToken(tokenResponse.accessToken)
        if let refreshToken = tokenResponse.refreshToken {
            try await keychainManager.saveSpotifyRefreshToken(refreshToken)
        }

        let isPremium = await checkPremiumStatus(accessToken: tokenResponse.accessToken)

        Logger.spotifyService.info("Spotify authorization successful, premium: \(isPremium)")
        return await SpotifyAuthResult(isAuthorized: true, hasSpotifyPremium: isPremium)
    }

    // MARK: - Token Check

    public func hasAccessToken() async -> Bool {
        (try? await keychainManager.loadSpotifyAccessToken()) != nil
    }

    /// Pings `/me` with the saved access token. On 401 attempts a refresh and retries.
    /// Distinguishes "no token at all" from "token can't be revived" so the caller can
    /// choose whether to prompt for re-auth.
    public func verifyConnection() async -> SpotifyConnectionState {
        guard var token = try? await keychainManager.loadSpotifyAccessToken() else {
            return .notConnected
        }

        do {
            let request = authenticatedRequest(url: SpotifyAPI.meURL, accessToken: token)
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            if statusCode == 200 {
                return .connected
            }

            if statusCode == 401 {
                Logger.spotifyService.info("Verify hit 401, attempting token refresh")
                do {
                    token = try await refreshAccessToken()
                    let retryRequest = authenticatedRequest(url: SpotifyAPI.meURL, accessToken: token)
                    let (_, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                    let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
                    return retryStatus == 200 ? .connected : .invalid
                } catch {
                    Logger.spotifyService.error("Token refresh failed during verify: \(error)")
                    return .invalid
                }
            }

            Logger.spotifyService.error("Verify failed with status \(statusCode)")
            return .invalid
        } catch {
            Logger.spotifyService.error("Verify request threw: \(error)")
            return .invalid
        }
    }

    // MARK: - Recently Played

    public func fetchRecentlyPlayed() async throws {
        guard let accessToken = try await keychainManager.loadSpotifyAccessToken() else {
            Logger.spotifyService.error("No Spotify access token found")
            throw SpotifyAuthError.missingAccessToken
        }

        let (data, response) = try await URLSession.shared.data(
            for: authenticatedRequest(url: "\(SpotifyAPI.recentlyPlayedURL)?limit=10", accessToken: accessToken)
        )

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if statusCode == 401 {
            Logger.spotifyService.info("Access token expired, attempting refresh")
            let newAccessToken = try await refreshAccessToken()
            let (retryData, retryResponse) = try await URLSession.shared.data(
                for: authenticatedRequest(url: "\(SpotifyAPI.recentlyPlayedURL)?limit=10", accessToken: newAccessToken)
            )
            guard let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
                Logger.spotifyService.error("Recently played request failed after refresh with status: \(retryStatus)")
                throw SpotifyAuthError.requestFailed(statusCode: retryStatus)
            }
            let json = try JSONSerialization.jsonObject(with: retryData)
            Logger.spotifyService.info("Recently played response: \(String(describing: json))")
            return
        }

        guard statusCode == 200 else {
            Logger.spotifyService.error("Recently played request failed with status: \(statusCode)")
            throw SpotifyAuthError.requestFailed(statusCode: statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data)
        Logger.spotifyService.info("Recently played response: \(String(describing: json))")
    }

    // MARK: - Album Search

    public func searchAlbumId(name: String, artist: String) async -> String? {
        guard var accessToken = try? await keychainManager.loadSpotifyAccessToken() else {
            Logger.spotifyService.info("Album search skipped — no Spotify access token")
            return nil
        }

        // Spotify search treats `:` and unescaped double-quotes as field/operator syntax.
        // Wrap the field values in double quotes (the documented way to match exact phrases)
        // and strip embedded quotes so values like `Look: An EP` or `Dr. Dre` don't corrupt
        // the query (e.g. `album:"Look: An EP" artist:"Dr. Dre"`).
        let sanitizedName = name.replacingOccurrences(of: "\"", with: "")
        let sanitizedArtist = artist.replacingOccurrences(of: "\"", with: "")
        let query = "album:\"\(sanitizedName)\" artist:\"\(sanitizedArtist)\""
        guard var components = URLComponents(string: SpotifyAPI.searchURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "album"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else { return nil }

        do {
            var (data, response) = try await URLSession.shared.data(
                for: authenticatedRequest(url: url.absoluteString, accessToken: accessToken)
            )
            var statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            if statusCode == 401 {
                Logger.spotifyService.info("Search hit 401, refreshing token")
                accessToken = try await refreshAccessToken()
                (data, response) = try await URLSession.shared.data(
                    for: authenticatedRequest(url: url.absoluteString, accessToken: accessToken)
                )
                statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            }

            guard statusCode == 200 else {
                Logger.spotifyService.error("Spotify search failed status \(statusCode)")
                return nil
            }

            let decoded = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            let id = decoded.albums?.items.first?.id
            Logger.spotifyService.info("Spotify search resolved album id: \(id ?? "nil")")
            return id
        } catch {
            Logger.spotifyService.error("Spotify search threw: \(error)")
            return nil
        }
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = try await keychainManager.loadSpotifyRefreshToken() else {
            Logger.spotifyService.error("No refresh token available")
            throw SpotifyAuthError.refreshTokenMissing
        }

        var request = URLRequest(url: URL(string: SpotifyAPI.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "\(SpotifyAPI.Param.grantType)=refresh_token",
            "refresh_token=\(refreshToken)",
            "\(SpotifyAPI.Param.clientId)=\(clientId)"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            Logger.spotifyService.error("Token refresh failed")
            throw SpotifyAuthError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)

        try await keychainManager.saveSpotifyAccessToken(tokenResponse.accessToken)
        if let newRefreshToken = tokenResponse.refreshToken {
            try await keychainManager.saveSpotifyRefreshToken(newRefreshToken)
        }

        Logger.spotifyService.info("Token refresh successful")
        return tokenResponse.accessToken
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Base64URL.encode(Data(bytes))
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Base64URL.encode(Data(hash))
    }

    // MARK: - Auth Session

    private func startAuthSession(codeChallenge: String) async throws -> String {
        var components = URLComponents(string: SpotifyAPI.authURL)!
        components.queryItems = [
            URLQueryItem(name: SpotifyAPI.Param.clientId, value: clientId),
            URLQueryItem(name: SpotifyAPI.Param.responseType, value: "code"),
            URLQueryItem(name: SpotifyAPI.Param.redirectUri, value: redirectUri.absoluteString),
            URLQueryItem(name: SpotifyAPI.Param.codeChallengeMethod, value: "S256"),
            URLQueryItem(name: SpotifyAPI.Param.codeChallenge, value: codeChallenge),
            URLQueryItem(name: SpotifyAPI.Param.scope, value: SpotifyAPI.scopes)
        ]

        let url = components.url!
        let scheme = redirectUri.scheme!

        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let session = ASWebAuthenticationSession(url: url, callback: .customScheme(scheme)) { callbackURL, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL,
                          let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == SpotifyAPI.Param.code })?.value else {
                        continuation.resume(throwing: SpotifyAuthError.missingAuthCode)
                        return
                    }
                    continuation.resume(returning: code)
                }
                session.presentationContextProvider = SpotifyPresentationContext.shared
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
        }
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> SpotifyTokenResponse {
        var request = URLRequest(url: URL(string: SpotifyAPI.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "\(SpotifyAPI.Param.grantType)=authorization_code",
            "\(SpotifyAPI.Param.code)=\(code)",
            "\(SpotifyAPI.Param.redirectUri)=\(redirectUri.absoluteString)",
            "\(SpotifyAPI.Param.clientId)=\(clientId)",
            "\(SpotifyAPI.Param.codeVerifier)=\(codeVerifier)"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            Logger.spotifyService.error("Token exchange failed")
            throw SpotifyAuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
    }

    // MARK: - Premium Check

    private func checkPremiumStatus(accessToken: String) async -> Bool {
        let request = authenticatedRequest(url: SpotifyAPI.meURL, accessToken: accessToken)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(SpotifyUserResponse.self, from: data)
            return user.product == "premium"
        } catch {
            Logger.spotifyService.error("Premium check failed: \(error)")
            return false
        }
    }

    // MARK: - Helpers

    private func authenticatedRequest(url: String, accessToken: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}

// MARK: - Base64URL Encoding (nonisolated to opt out of MainActor default isolation)

private nonisolated enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Private Response Models (nonisolated for Decodable conformance in actor context)

private nonisolated struct SpotifyTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private nonisolated struct SpotifyUserResponse: Decodable, Sendable {
    let product: String?
}

private nonisolated struct SpotifySearchResponse: Decodable, Sendable {
    let albums: SpotifyAlbumsPage?

    struct SpotifyAlbumsPage: Decodable, Sendable {
        let items: [SpotifyAlbumItem]
    }

    struct SpotifyAlbumItem: Decodable, Sendable {
        let id: String
    }
}

// MARK: - Error

nonisolated enum SpotifyAuthError: Error, LocalizedError {
    case missingAuthCode
    case missingAccessToken
    case tokenExchangeFailed
    case refreshTokenMissing
    case tokenRefreshFailed
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAuthCode: "No authorization code received from Spotify"
        case .missingAccessToken: "No Spotify access token found"
        case .tokenExchangeFailed: "Failed to exchange authorization code for access token"
        case .refreshTokenMissing: "No refresh token available — re-authorization required"
        case .tokenRefreshFailed: "Failed to refresh Spotify access token"
        case .requestFailed(let statusCode): "Spotify API request failed with status \(statusCode)"
        }
    }
}

// MARK: - Presentation Context

@MainActor
private final class SpotifyPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = SpotifyPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let activeScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard let scene = activeScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            // No window scenes available — should not happen in a running app
            fatalError("No UIWindowScene available to present authentication")
        }
        return scene.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor(windowScene: scene)
    }
}
