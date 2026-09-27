//
//  AccountGuestDataModel.swift
//  Account
//

import SwiftUI
import CoreApp
import Analytics


@MainActor
@Observable
final class AccountGuestDataModel {
    
    let sessionManager: SessionManager
    private let analyticsManager: AnalyticsManager
    
    init(sessionManager: SessionManager = .shared,
         analyticsManager: AnalyticsManager = .shared) {
        self.sessionManager = sessionManager
        self.analyticsManager = analyticsManager
    }

    func track(_ event: AnalyticsEvent) {
        analyticsManager.log(event)
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
        analyticsManager.log(.guestSignInTap)
        sessionManager.requestLogin(reason: .account)
    }
}
