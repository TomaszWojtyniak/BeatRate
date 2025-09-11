//
//  AppDataModel.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 13/06/2025.
//'

import SwiftUI
import Analytics
import OSLog

@Observable
@MainActor
class AppDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    
    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    func setUserId(_ userId: String) {
        Task {
            self.analyticsManager.setUserId(userId)
            self.crashLogger.setUserIdentifier(userId)
            Logger.app.debug("Set user id for crashlytics and analytics")
        }
    }
}
