//
//  AppDataModel.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 13/06/2025.
//'

import SwiftUI
import Analytics
import OSLog
import SwiftData
import AppUseCases
import Models

@Observable
@MainActor
class AppDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    private let getAppUseCase: GetAppUseCaseProtocol
    
    var user: User?
    
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
}
