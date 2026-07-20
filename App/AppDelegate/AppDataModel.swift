//
//  AppDataModel.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 13/06/2025.
//'

import SwiftUI
import Analytics
import OSLog
import AppUseCases
import Models
import CoreApp

@Observable
@MainActor
class AppDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    private let getAppUseCase: GetAppUseCaseProtocol

    var user: User?
    var isUserLoggedIn: Bool = false
    var showingSplash = true

    /// `SessionManager` passthrough. The manager is the app-wide source of truth,
    /// but views reach it through here rather than touching the singleton directly.
    /// Reading its properties inside these accessors still registers `@Observable`
    /// tracking with the caller, so `AppView` re-renders on session changes.
    var isPresentingLoginPrompt: Bool {
        get { SessionManager.shared.isPresentingLoginPrompt }
        set { SessionManager.shared.isPresentingLoginPrompt = newValue }
    }

    var loginPromptReason: LoginPromptReason {
        SessionManager.shared.loginPromptReason
    }

    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared,
         getAppUseCase: GetAppUseCaseProtocol = GetAppUseCase()) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.getAppUseCase = getAppUseCase
    }
    
    func setUserId() {
        // The `User` row survives a logout with its `userId` intact — only
        // `isLoggedIn` flips — so check that too, or a guest keeps reporting under
        // the previous account's identity.
        guard let user, user.isLoggedIn, !user.userId.isEmpty else {
            // Expected while browsing as a guest — there's no account to attribute
            // analytics or crash reports to yet.
            Logger.app.debug("No user id to set - browsing as guest")
            return
        }
        let userId = user.userId
        self.analyticsManager.setUserId(userId)
        self.crashLogger.setUserIdentifier(userId)
        Logger.app.debug("Set user id for crashlytics and analytics")
    }
    
    func getCurrentUser() async {
        do {
            self.user = try await self.getAppUseCase.getCurrentUser()
        } catch let error {
            Logger.app.error("Cant get current user: \(error)")
        }
    }

    func startObservingLoginState() {
        Task {
            for await isLoggedIn in getAppUseCase.observeLoginState() {
                let wasLoggedOut = !self.isUserLoggedIn
                self.isUserLoggedIn = isLoggedIn

                // `observeLoginState()` hands out a single shared stream, so this
                // stays the only consumer and mirrors the value into the
                // synchronously-readable session state views branch on.
                SessionManager.shared.update(isLoggedIn: isLoggedIn)

                // Only reset splash screen on state transition from logged out to logged in
                // This prevents splash from appearing when user is already in the app
                if isLoggedIn && wasLoggedOut {
                    self.showingSplash = true
                    Logger.app.debug("User logged in - showing splash screen")
                }

                Logger.app.debug("Login state changed: \(isLoggedIn)")
            }
        }
    }

    func checkInitialLoginStatus() async {
        isUserLoggedIn = await getAppUseCase.isUserLoggedIn()
        SessionManager.shared.update(isLoggedIn: isUserLoggedIn)
        Logger.app.debug("Initial user logged in status: \(self.isUserLoggedIn)")
    }
}
