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
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    func setUserId(_ userId: String) {
        Task {
            await self.analyticsManager.setUserId(userId)
            await self.crashLogger.setUserIdentifier(userId)
            Self.logger.debug("Set user id for crashlytics and analytics")
        }
    }
}
