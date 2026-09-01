//
//  SpotifyFailure.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Every way a Spotify operation can fail, kept deliberately distinct.
///
/// The bug this type exists to prevent: collapsing "the network blipped" and
/// "this session is dead" into one error, which made callers sign the user out
/// on a dropped connection. `.transient` must never mutate stored tokens and
/// must never trigger a re-auth prompt.
public nonisolated enum SpotifyFailure: Error, LocalizedError, Sendable, Equatable {
    /// No tokens stored — the user has never connected, or was signed out.
    case noSession
    /// Spotify rejected the refresh token. Re-authorization is genuinely required.
    case sessionExpired
    /// HTTP 403. In Development Mode this means the account is not on the
    /// dashboard allowlist; it can also mean a missing OAuth scope.
    case notAllowlisted
    /// HTTP 429. Quota is shared across all Client IDs on the developer account.
    case rateLimited(retryAfter: TimeInterval?)
    /// Offline, timed out, or a 5xx. The session is fine — retry later.
    case transient
    /// The user dismissed the authorization sheet. Not an error to surface.
    case authCancelled
    /// The sheet could not start, or returned no authorization code.
    case authorizationFailed

    public var errorDescription: String? {
        switch self {
        case .noSession: "No Spotify session — connect your account to continue"
        case .sessionExpired: "Your Spotify session expired — reconnect to continue"
        case .notAllowlisted: "This Spotify account isn't enabled for BeatRate"
        case .rateLimited: "Spotify is limiting requests — try again shortly"
        case .transient: "Couldn't reach Spotify — check your connection"
        case .authCancelled: "Spotify sign-in was cancelled"
        case .authorizationFailed: "Spotify sign-in couldn't be completed"
        }
    }
}
