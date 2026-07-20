//
//  AccountGuestDataModel.swift
//  Account
//

import SwiftUI
import CoreApp

/// Session surface for the Account tab's guest path.
///
/// `AccountNavigationStack` branches on ``isLoggedIn`` and `AccountGuestView` drives
/// the sign-in prompt through here, so neither view touches `SessionManager`
/// directly. Reading the manager's properties inside these accessors still registers
/// `@Observable` tracking with the calling view, so the branch re-renders on login.
@MainActor
@Observable
final class AccountGuestDataModel {

    var isLoggedIn: Bool {
        SessionManager.shared.isLoggedIn
    }

    /// Raises the prompt the first time a guest opens the Account tab, then stays
    /// quiet. Suppressed entirely after an explicit logout.
    func autoPromptIfNeeded() {
        SessionManager.shared.autoPromptForAccountIfNeeded()
    }

    func requestLogin() {
        SessionManager.shared.requestLogin(reason: .account)
    }
}
