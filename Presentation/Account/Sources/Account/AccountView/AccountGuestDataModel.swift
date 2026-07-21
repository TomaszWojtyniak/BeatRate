//
//  AccountGuestDataModel.swift
//  Account
//

import SwiftUI
import CoreApp


@MainActor
@Observable
final class AccountGuestDataModel {
    
    let sessionManager: SessionManager
    
    init(sessionManager: SessionManager = .shared) {
        self.sessionManager = sessionManager
    }

    var isLoggedIn: Bool {
        sessionManager.isLoggedIn
    }

    /// Raises the prompt the first time a guest opens the Account tab, then stays
    /// quiet. Suppressed entirely after an explicit logout.
    func autoPromptIfNeeded() {
        sessionManager.autoPromptForAccountIfNeeded()
    }

    func requestLogin() {
        sessionManager.requestLogin(reason: .account)
    }
}
