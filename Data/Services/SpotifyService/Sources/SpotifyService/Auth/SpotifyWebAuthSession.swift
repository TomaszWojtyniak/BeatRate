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

    /// Resolved once, at construction, so `presentationAnchor` is total without a
    /// fallback: iOS 26 deprecated every scene-less `UIWindow` initializer, and
    /// the alternatives there were a deprecation warning or trapping mid-OAuth.
    /// Failing construction instead pushes the one real failure — no window scene
    /// to present on — to the caller, which already throws `authorizationFailed`.
    /// Callers build this immediately before authorizing, so the anchor cannot go
    /// stale between here and presentation.
    private let anchor: ASPresentationAnchor

    /// Nil when there is no window scene to present on. A factory rather than a
    /// failable `init?()`, which cannot override `NSObject.init()`.
    static func make() -> SpotifyWebAuthSession? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return nil
        }
        let window = scene.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor(windowScene: scene)
        return SpotifyWebAuthSession(anchor: window)
    }

    private init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
        super.init()
    }

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
            // start() returning false means the completion handler will never
            // fire — resume here or the continuation (and caller) hangs forever.
            guard session.start() else {
                continuation.resume(throwing: SpotifyFailure.authorizationFailed)
                return
            }
        }
    }

    private nonisolated static func authorizationCode(
        from callbackURL: URL?,
        error: Error?
    ) -> Result<String, Error> {
        if let error {
            // Dismissing the sheet is a choice, not a failure — callers must not
            // surface it as an error.
            let isCancellation = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            return .failure(isCancellation ? SpotifyFailure.authCancelled : SpotifyFailure.authorizationFailed)
        }
        guard let callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == SpotifyAPI.Param.code })?.value else {
            return .failure(SpotifyFailure.authorizationFailed)
        }
        return .success(code)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
