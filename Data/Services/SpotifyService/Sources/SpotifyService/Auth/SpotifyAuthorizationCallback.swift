//
//  SpotifyAuthorizationCallback.swift
//  SpotifyService
//

import Foundation
import AuthenticationServices
import Analytics

/// Reads the sign-in sheet's outcome: the `code` from Spotify's redirect, or why there is none.
public enum SpotifyAuthorizationCallback {
    nonisolated public static func authorizationCode(
        from callbackURL: URL?,
        error: Error?
    ) -> Result<String, Error> {
        if let error {
            // Dismissing the sheet is a choice, not a failure — callers must not
            // surface it as an error.
            let isCancellation = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            if isCancellation {
                CrashLogger.log("Sign-in sheet dismissed by the user", to: .spotifyService, level: .info)
            } else {
                CrashLogger.log("Sign-in sheet failed: \(error)", to: .spotifyService)
            }
            return .failure(isCancellation ? SpotifyFailure.authCancelled : SpotifyFailure.authorizationFailed)
        }
        let queryItems = callbackURL.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems
        } ?? []
        guard let code = queryItems.first(where: { $0.name == SpotifyAPI.Param.code })?.value else {
            // Spotify reports a declined consent screen as `?error=access_denied`.
            let spotifyError = queryItems.first(where: { $0.name == "error" })?.value ?? "none"
            CrashLogger.log("Callback without authorization code (callback: \(callbackURL != nil), error: \(spotifyError))", to: .spotifyService)
            return .failure(SpotifyFailure.authorizationFailed)
        }
        return .success(code)
    }
}
