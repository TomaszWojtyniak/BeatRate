//
//  LoginDataModel.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 27/05/2025.
//

import SwiftUI
import LoginUseCases
import Analytics

@Observable
@MainActor
class LoginDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    let analyticsManager: AnalyticsManager
    
    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         analyticsManager: AnalyticsManager = .shared) {
        self.getLoginUseCase = getLoginUseCase
        self.analyticsManager = analyticsManager
    }
    
    func trackAnalytics(eventName: String, parameter: [String: String]? = nil) {
        Task {
            await self.analyticsManager.track(AppAnalyticsEvent.custom(eventName: eventName, parameters: parameter))
        }
    }
    
    func getLoginData() async {
        await self.getLoginUseCase.getLoginData()
    }
}

