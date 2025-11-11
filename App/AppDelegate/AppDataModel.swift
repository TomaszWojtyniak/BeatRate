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

    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared,
         getAppUseCase: GetAppUseCaseProtocol = GetAppUseCase()) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.getAppUseCase = getAppUseCase
    }
    
    func setUserId() {
        guard let userId = user?.userId else {
            Logger.app.error("Cant get current userId")
            return
        }
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
                self.isUserLoggedIn = isLoggedIn

                // Reset splash screen when user logs in
                if isLoggedIn {
                    self.showingSplash = true
                }

                Logger.app.debug("Login state changed: \(isLoggedIn)")
            }
        }
    }

    func checkInitialLoginStatus() async {
        isUserLoggedIn = await getAppUseCase.isUserLoggedIn()
        Logger.app.debug("Initial user logged in status: \(self.isUserLoggedIn)")
    }
}
