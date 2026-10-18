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

/// Facade over `SpotifySession` (tokens) and `SpotifyClient` (endpoints).
/// Callers above this layer see one small surface and never touch either.
public actor SpotifyService: SpotifyServiceProtocol {
    public static let shared = SpotifyService()

    private let session: SpotifySession
    private let client: SpotifyClient

    public init(
        clientId: String = AppEnvironment.current.spotifyClientId,
        redirectUri: String = AppEnvironment.current.spotifyRedirectUri,
        keychainManager: KeychainManager = .shared
    ) {
        guard let url = URL(string: redirectUri), let scheme = url.scheme else {
            preconditionFailure("Invalid Spotify redirect URI: \(redirectUri)")
        }
        let transport = URLSessionTransport()
        self.session = SpotifySession(
            tokenStore: SpotifyTokenStore(keychain: keychainManager),
            transport: transport,
            clientId: clientId,
            redirectUri: url,
            callbackScheme: scheme
        )
        self.client = SpotifyClient(transport: transport)
    }

    /// Test/preview seam.
    init(session: SpotifySession, client: SpotifyClient) {
        self.session = session
        self.client = client
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws -> SpotifyAuthResult {
        CrashLogger.log("Connect: starting authorization", to: .spotifyService, level: .info)
        _ = try await session.authorize()

        // Premium comes from the same /me call the connection check uses, so
        // connecting costs one request rather than two.
        let premium = await currentPremiumStatus()
        CrashLogger.log("Connect: authorized, premium: \(premium)", to: .spotifyService, level: .info)
        CrashLogger.setValue("connected", forKey: "spotify_connection")
        CrashLogger.setValue("\(premium)", forKey: "spotify_premium")
        return SpotifyAuthResult(isAuthorized: true, premium: premium)
    }

    // MARK: - Connection State

    public func hasStoredSession() async -> Bool {
        await session.hasStoredSession()
    }

    /// Pings `/me` and reports what actually happened. The old implementation
    /// collapsed every error into "invalid", so a dropped connection at launch
    /// forced a full reconnect.
    public func verifyConnection() async -> SpotifyConnectionState {
        let state = await checkConnection()
        CrashLogger.log("Connection check: \(state)", to: .spotifyService, level: .info)
        CrashLogger.setValue("\(state)", forKey: "spotify_connection")
        return state
    }

    private func checkConnection() async -> SpotifyConnectionState {
        do {
            let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session)
            return .connected(premium: SpotifyPremiumStatus(product: user.product))
        } catch SpotifyFailure.noSession {
            return .notConnected
        } catch SpotifyFailure.sessionExpired {
            CrashLogger.log("Connection check: session expired, reconnect required", to: .spotifyService)
            return .needsReauth
        } catch SpotifyFailure.notAllowlisted {
            CrashLogger.log("Connection check: account is not on the Development Mode allowlist", to: .spotifyService)
            return .notAllowlisted
        } catch {
            // Transient, rate-limited, or unrecognized: the session is probably
            // fine. Do not prompt the user to reconnect.
            CrashLogger.log("Connection check unavailable: \(error)", to: .spotifyService)
            return .unavailable
        }
    }

    // MARK: - Recently Played

    public func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum] {
        CrashLogger.log("Recently played: fetching", to: .spotifyService, level: .info)
        let response: SpotifyRecentlyPlayedResponse = try await client.get(
            SpotifyAPI.recentlyPlayed(limit: SpotifyAPI.Limit.recentlyPlayedPage),
            session: session
        )
        let albums = response.uniqueAlbums
        CrashLogger.log("Recently played: \(response.items.count) tracks → \(albums.count) unique albums", to: .spotifyService, level: .info)
        return albums
    }

    // MARK: - Premium

    private func currentPremiumStatus() async -> SpotifyPremiumStatus {
        do {
            let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session)
            CrashLogger.log("Premium check: product \(user.product ?? "nil")", to: .spotifyService, level: .info)
            return SpotifyPremiumStatus(product: user.product)
        } catch {
            // Unknown, never "free" — a failed check must not read as a downgrade.
            CrashLogger.log("Premium check failed: \(error)", to: .spotifyService)
            return .unknown
        }
    }
}
