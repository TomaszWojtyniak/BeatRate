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
import CryptoKit

@Observable
@MainActor
class LoginDataModel: NSObject {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let postLoginUseCase: SetLoginUseCaseProtocol
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    var isShowingErrorAlert: Bool = false
    
    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         postLoginUseCase: SetLoginUseCaseProtocol = SetLoginUseCase(),
         analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared) {
        self.getLoginUseCase = getLoginUseCase
        self.postLoginUseCase = postLoginUseCase
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    func handleLoginFlow(authResult: ASAuthorization) async throws -> String {
        return try await self.postLoginUseCase.setLoginData(authResult: authResult)
    }
    
    func handleLoginFailure(error: Error) async {
        Self.logger.debug("Login failed: \(error)")
        await self.crashLogger.recordError(error)
        self.isShowingErrorAlert = true
    }
    
    func getCurrentNonce() async -> String {
        await self.getLoginUseCase.getCurrentNonce()
    }
    
    func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
      }.joined()

      return hashString
    }
}


