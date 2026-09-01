//
//  SpotifyTokens.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// The stored Spotify credential set. Persisted as a single JSON Keychain item
/// so it can never be half-written.
nonisolated struct SpotifyTokens: Sendable, Equatable, Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    /// Refresh this far ahead of real expiry so an in-flight request can't
    /// straddle the boundary and eat an avoidable 401.
    static let refreshLeeway: TimeInterval = 60

    func isFresh(at now: Date = Date()) -> Bool {
        expiresAt.timeIntervalSince(now) > Self.refreshLeeway
    }

    /// Carries the previous refresh token forward when Spotify omits it —
    /// a refresh response only includes one when it rotates.
    func merging(_ response: SpotifyTokenResponse, issuedAt: Date = Date()) -> SpotifyTokens {
        SpotifyTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: issuedAt.addingTimeInterval(response.expiresIn ?? SpotifyTokenResponse.defaultLifetime)
        )
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decoded(from data: Data) throws -> SpotifyTokens {
        try JSONDecoder().decode(SpotifyTokens.self, from: data)
    }
}
