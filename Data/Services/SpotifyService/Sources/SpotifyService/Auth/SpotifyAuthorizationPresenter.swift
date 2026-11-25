//
//  SpotifyAuthorizationPresenter.swift
//  SpotifyService
//

import Foundation

/// Shows the Spotify sign-in sheet and returns the authorization code from the
/// redirect. A seam so the rest of `SpotifySession.authorize()` can be tested.
nonisolated public protocol SpotifyAuthorizationPresenter: Sendable {
    func authorize(url: URL, callbackScheme: String) async throws -> String
}
