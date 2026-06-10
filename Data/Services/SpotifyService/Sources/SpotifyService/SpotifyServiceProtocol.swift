//
//  SpotifyServiceProtocol.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

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
    func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum]
    func hasAccessToken() async -> Bool
    func searchAlbumId(name: String, artist: String) async -> String?
    func verifyConnection() async -> SpotifyConnectionState
}
