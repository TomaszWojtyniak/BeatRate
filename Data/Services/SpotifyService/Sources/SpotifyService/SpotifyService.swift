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
        Logger.spotifyService.info("Starting Spotify authorization")
        _ = try await session.authorize()

        // Premium comes from the same /me call the connection check uses, so
        // connecting costs one request rather than two.
        let premium = await currentPremiumStatus()
        Logger.spotifyService.info("Spotify authorized, premium: \(String(describing: premium))")
        return await SpotifyAuthResult(isAuthorized: true, premium: premium)
    }

    // MARK: - Connection State

    public func hasStoredSession() async -> Bool {
        await session.hasStoredSession()
    }

    /// Pings `/me` and reports what actually happened. The old implementation
    /// collapsed every error into "invalid", so a dropped connection at launch
    /// forced a full reconnect.
    public func verifyConnection() async -> SpotifyConnectionState {
        do {
            let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session)
            return .connected(premium: await SpotifyPremiumStatus(product: user.product))
        } catch SpotifyFailure.noSession {
            return .notConnected
        } catch SpotifyFailure.sessionExpired {
            return .needsReauth
        } catch SpotifyFailure.notAllowlisted {
            Logger.spotifyService.error("Spotify account is not on the Development Mode allowlist")
            return .notAllowlisted
        } catch {
            // Transient, rate-limited, or unrecognized: the session is probably
            // fine. Do not prompt the user to reconnect.
            Logger.spotifyService.error("Spotify connection check unavailable: \(error)")
            return .unavailable
        }
    }

    // MARK: - Recently Played

    public func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum] {
        let response: SpotifyRecentlyPlayedResponse = try await client.get(
            SpotifyAPI.recentlyPlayed(limit: SpotifyAPI.Limit.recentlyPlayedPage),
            session: session
        )
        let albums = response.uniqueAlbums
        Logger.spotifyService.info("Resolved \(albums.count) recently-played Spotify albums")
        return albums
    }

    // MARK: - Premium

    private func currentPremiumStatus() async -> SpotifyPremiumStatus {
        do {
            let user: SpotifyUserResponse = try await client.get(SpotifyAPI.me, session: session)
            return await SpotifyPremiumStatus(product: user.product)
        } catch {
            // Unknown, never "free" — a failed check must not read as a downgrade.
            Logger.spotifyService.error("Spotify premium check failed: \(error)")
            return .unknown
        }
    }
}
