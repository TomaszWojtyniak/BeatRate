//
//  SpotifyTokenStore.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation
import CoreApp

/// Reads and writes the Spotify token set. Protocol-backed so `SpotifySession`
/// can be tested without touching the Keychain.
nonisolated protocol SpotifyTokenStoring: Sendable {
    func load() async throws -> SpotifyTokens?
    func save(_ tokens: SpotifyTokens) async throws
    func clear() async throws
}

/// Keychain-backed store. Persists the token set as one JSON item.
nonisolated struct SpotifyTokenStore: SpotifyTokenStoring {
    let keychain: KeychainManager

    func load() async throws -> SpotifyTokens? {
        if let data = try await keychain.loadSpotifyTokens() {
            return try SpotifyTokens.decoded(from: data)
        }
        return try await migrateLegacyTokensIfPresent()
    }

    func save(_ tokens: SpotifyTokens) async throws {
        try await keychain.saveSpotifyTokens(tokens.encoded())
    }

    func clear() async throws {
        try await keychain.deleteSpotifyTokens()
    }

    /// Users who connected before the single-item format have a separate access
    /// and refresh token on file. Fold them into the new shape rather than
    /// signing them out — which would be an ironic way to ship this fix.
    ///
    /// The old format stored no expiry, so treat the access token as already
    /// stale: the first request refreshes it, which is correct and cheap.
    private func migrateLegacyTokensIfPresent() async throws -> SpotifyTokens? {
        guard let pair = try await keychain.loadLegacySpotifyTokenPair() else { return nil }
        let tokens = SpotifyTokens(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresAt: .distantPast
        )
        try await save(tokens)
        try await keychain.deleteLegacySpotifyTokens()
        return tokens
    }
}
