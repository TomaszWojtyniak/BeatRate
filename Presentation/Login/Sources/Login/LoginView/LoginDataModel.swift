//
//  LoginDataModel.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI
import LoginUseCases
import Analytics
import os

@Observable
@MainActor
class LoginDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared) {
        self.getLoginUseCase = getLoginUseCase
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    func trackAnalytics(eventName: String, parameter: [String: String]? = nil) {
        Task {
            await self.analyticsManager.track(AppAnalyticsEvent.custom(eventName: eventName, parameters: parameter))
        }
    }
    
    func getLoginData() async {
        Self.logger.debug("Get login data started")
        await self.getLoginUseCase.getLoginData()
        await self.crashLogger.debug("Get login data finished")
    }
}

