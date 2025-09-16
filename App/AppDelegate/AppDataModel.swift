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

@Observable
@MainActor
class AppDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    private let getAppUseCase: GetAppUseCaseProtocol
    
    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared,
         getAppUseCase: GetAppUseCaseProtocol = GetAppUseCase()) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.getAppUseCase = getAppUseCase
    }
    
    func setUserId(_ userId: String) {
        Task {
            self.analyticsManager.setUserId(userId)
            self.crashLogger.setUserIdentifier(userId)
            Logger.app.debug("Set user id for crashlytics and analytics")
        }
    }
    
    func context() -> ModelContext {
        self.getAppUseCase.context()
    }
}
