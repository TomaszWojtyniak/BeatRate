//
//  SpotifyError.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

nonisolated enum SpotifyError: Error, LocalizedError {
    case authorizationFailedToStart
    case missingAuthCode
    case missingAccessToken
    case invalidResponse
    case tokenExchangeFailed
    case refreshTokenMissing
    case tokenRefreshFailed
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .authorizationFailedToStart: "Unable to start the Spotify authorization session"
        case .missingAuthCode: "No authorization code received from Spotify"
        case .missingAccessToken: "No Spotify access token found"
        case .invalidResponse: "Spotify returned a non-HTTP response"
        case .tokenExchangeFailed: "Failed to exchange authorization code for access token"
        case .refreshTokenMissing: "No refresh token available — re-authorization required"
        case .tokenRefreshFailed: "Failed to refresh Spotify access token"
        case .requestFailed(let statusCode): "Spotify API request failed with status \(statusCode)"
        }
    }
}
