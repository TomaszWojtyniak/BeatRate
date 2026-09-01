//
//  SpotifyConnection.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Three-state on purpose. A failed check is `.unknown`, never `.free` —
/// reporting "not premium" because the network blipped is the bug this replaces.
public nonisolated enum SpotifyPremiumStatus: Sendable, Equatable {
    case premium
    case free
    case unknown

    /// `nil` for `.unknown` so an unknown value is never persisted as "false".
    public var isPremium: Bool? {
        switch self {
        case .premium: true
        case .free: false
        case .unknown: nil
        }
    }

    init(product: String?) {
        switch product {
        case SpotifyAPI.Value.premiumProduct: self = .premium
        case .some: self = .free
        case .none: self = .unknown
        }
    }
}

public nonisolated enum SpotifyConnectionState: Sendable, Equatable {
    /// A valid token is on file, verified against `/me`.
    case connected(premium: SpotifyPremiumStatus)
    /// No token stored — the user has never connected.
    case notConnected
    /// Spotify rejected the session and refresh failed. Re-auth required.
    case needsReauth
    /// Transient failure. The session may be perfectly fine — never prompt.
    case unavailable
    /// HTTP 403. In Development Mode, the account is not on the allowlist.
    case notAllowlisted

    /// Whether this state warrants asking the user to reconnect. Only a genuinely
    /// dead session qualifies.
    public var requiresUserAction: Bool {
        switch self {
        case .needsReauth: true
        case .connected, .notConnected, .unavailable, .notAllowlisted: false
        }
    }
}
