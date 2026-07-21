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
    private let sessionManager: SessionManager

    var user: User?
    var isUserLoggedIn: Bool = false
    var showingSplash = true

    var isPresentingLoginPrompt: Bool {
        get { sessionManager.isPresentingLoginPrompt }
        set { sessionManager.isPresentingLoginPrompt = newValue }
    }

    var loginPromptReason: LoginPromptReason {
        sessionManager.loginPromptReason
    }

    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared,
         sessionManager: SessionManager = .shared,
         getAppUseCase: GetAppUseCaseProtocol = GetAppUseCase()) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.getAppUseCase = getAppUseCase
        self.sessionManager = sessionManager
    }
    
    func setUserId() {
        guard let user, user.isLoggedIn, !user.userId.isEmpty else {
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
                sessionManager.update(isLoggedIn: isLoggedIn)

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
        sessionManager.update(isLoggedIn: isUserLoggedIn)
        Logger.app.debug("Initial user logged in status: \(self.isUserLoggedIn)")
    }
}
