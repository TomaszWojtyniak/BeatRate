//
//  SpotifyWebAuthSession.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation
import AuthenticationServices
import UIKit

/// Drives the ASWebAuthenticationSession OAuth sheet on the main actor and keeps
/// the session alive for the duration of the flow — the system does not retain it.
@MainActor
final class SpotifyWebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?

    /// Presents the authorization sheet and returns the `code` query item from
    /// the redirect callback.
    func authorize(url: URL, callbackScheme: String) async throws -> String {
        defer { activeSession = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(callbackScheme)
            ) { callbackURL, error in
                continuation.resume(with: Self.authorizationCode(from: callbackURL, error: error))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            session.start()
        }
    }

    private nonisolated static func authorizationCode(
        from callbackURL: URL?,
        error: Error?
    ) -> Result<String, Error> {
        if let error {
            return .failure(error)
        }
        guard let callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == SpotifyAPI.Param.code })?.value else {
            return .failure(SpotifyError.missingAuthCode)
        }
        return .success(code)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let activeScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard let scene = activeScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            // No window scenes available — should not happen in a running app
            fatalError("No UIWindowScene available to present authentication")
        }
        return scene.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor(windowScene: scene)
    }
}
