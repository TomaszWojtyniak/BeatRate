//
//  SessionManager.swift
//  CoreApp
//

import Foundation
import Analytics
import OSLog

/// Why the login prompt was raised. Drives the sheet's headline copy.
public enum LoginPromptReason: Sendable {
    /// The guest opened the locked Account tab.
    case account
    /// The guest tried to rate an album.
    case rating
}

/// App-wide, synchronously-readable session state.
///
/// Views need to answer "is this a guest?" while rendering, but the login flag
/// lives in SwiftData behind an `async` call. This holds the last known value so
/// `AccountNavigationStack`, `AlbumDetailsView` and friends can branch without a
/// `Task`.
///
/// - Important: This deliberately does **not** subscribe to
///   `SwiftDataManager.observeLoginState()`. That method hands out a single
///   shared `AsyncStream`, so a second consumer would steal events from
///   `AppDataModel`. `AppDataModel` stays the only consumer and pushes changes
///   here via ``update(isLoggedIn:)``.
@Observable
@MainActor
public final class SessionManager {
    public static let shared = SessionManager()

    /// Last known login state. `false` means guest — the app's default on a
    /// fresh install.
    public private(set) var isLoggedIn: Bool = false

    /// Drives the login sheet presented from `AppView`.
    public var isPresentingLoginPrompt: Bool = false

    public private(set) var loginPromptReason: LoginPromptReason = .account

    /// Whether the Account tab has already auto-raised the prompt this app session.
    /// Lives here rather than in the view so it survives the view being rebuilt.
    private var hasAutoPromptedAccount = false

    private init() {}

    /// Mirrors the authoritative login state. Called only from `AppDataModel`.
    ///
    /// A pure mirror: it deliberately infers nothing about *why* the state changed.
    /// Suppressing the Account auto-prompt used to be derived from the true→false
    /// transition here, but on a cold launch with revoked Apple credentials this
    /// races — `checkInitialLoginStatus()` and the splash's `forceLogout()` run
    /// concurrently, and whichever landed first decided whether the user ever got
    /// prompted to sign back in. Intent now arrives explicitly via ``userDidLogout()``.
    public func update(isLoggedIn: Bool) {
        guard self.isLoggedIn != isLoggedIn else { return }
        self.isLoggedIn = isLoggedIn
        if isLoggedIn {
            isPresentingLoginPrompt = false
        }
        Logger.app.debug("Session state: \(isLoggedIn ? "logged in" : "guest")")
    }

    /// Records that the user signed out *on purpose*, so the Account tab doesn't
    /// immediately shove a sign-in sheet back in their face. Call from the logout
    /// action itself, not from the resulting state change.
    public func userDidLogout() {
        hasAutoPromptedAccount = true
    }

    /// Raises the prompt the first time a guest opens the Account tab, then stays
    /// quiet — re-raising it on every visit would make the tab feel broken.
    public func autoPromptForAccountIfNeeded() {
        guard !isLoggedIn, !hasAutoPromptedAccount else { return }
        hasAutoPromptedAccount = true
        requestLogin(reason: .account)
    }

    /// Raises the login/sign-up sheet. No-op when already signed in.
    public func requestLogin(reason: LoginPromptReason) {
        guard !isLoggedIn else { return }
        loginPromptReason = reason
        isPresentingLoginPrompt = true
    }
}
