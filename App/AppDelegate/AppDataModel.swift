//
//  AppDataModel.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 13/06/2025.
//'

import SwiftUI
import Analytics
import SwiftDataManager
import OSLog
import SwiftData

@Observable
@MainActor
class AppDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    private let swiftDataManager: SwiftDataManager
    
    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared,
         swiftDataManager: SwiftDataManager = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
        self.swiftDataManager = swiftDataManager
    }
    
    func setUserId(_ userId: String) {
        Task {
            self.analyticsManager.setUserId(userId)
            self.crashLogger.setUserIdentifier(userId)
            Logger.app.debug("Set user id for crashlytics and analytics")
        }
    }
    
    func isDataLoaded() -> Bool {
        self.swiftDataManager.isDataLoaded
    }
    
    func context() -> ModelContext {
        self.swiftDataManager.context
    }
}
