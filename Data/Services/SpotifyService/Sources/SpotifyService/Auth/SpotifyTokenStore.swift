//
//  SpotifyTokenStore.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation
import CoreApp

/// Facade over the Keychain for the Spotify token pair.
nonisolated struct SpotifyTokenStore: Sendable {
    let keychain: KeychainManager

    func accessToken() async throws -> String? {
        try await keychain.loadSpotifyAccessToken()
    }

    func refreshToken() async throws -> String? {
        try await keychain.loadSpotifyRefreshToken()
    }

    /// Saves the access token and, when Spotify rotates it, the new refresh token.
    func persist(_ response: SpotifyTokenResponse) async throws {
        try await keychain.saveSpotifyAccessToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            try await keychain.saveSpotifyRefreshToken(refreshToken)
        }
    }
}
