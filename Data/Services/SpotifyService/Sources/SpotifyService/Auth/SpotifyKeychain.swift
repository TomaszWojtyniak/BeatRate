//
//  SpotifyKeychain.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation
import CoreApp

/// Exactly the Keychain surface the Spotify token store needs, so the
/// legacy-token migration can be tested without a real Keychain. Migration is
/// the one path here whose regression would sign out every existing user.
nonisolated protocol SpotifyKeychain: Sendable {
    func loadSpotifyTokens() async throws -> Data?
    func saveSpotifyTokens(_ data: Data) async throws
    func deleteSpotifyTokens() async throws
    func loadLegacySpotifyTokenPair() async throws -> (accessToken: String, refreshToken: String?)?
    func deleteLegacySpotifyTokens() async throws
}

extension KeychainManager: SpotifyKeychain {}
