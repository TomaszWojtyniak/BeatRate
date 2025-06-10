//
//  LoginDataModel.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI
import LoginUseCases
import Analytics
import AuthenticationServices
import os

@Observable
@MainActor
class LoginDataModel: NSObject {
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

}


