//
//  SpotifyServiceProtocol.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

public protocol SpotifyServiceProtocol: Sendable {
    func requestAuthorization() async throws -> SpotifyAuthResult
    func fetchRecentlyPlayedAlbums() async throws -> [SpotifyRecentAlbum]
    func hasStoredSession() async -> Bool
    func verifyConnection() async -> SpotifyConnectionState
}
