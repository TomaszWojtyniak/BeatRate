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
import OSLog
import CryptoKit

@Observable
@MainActor
final class LoginDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let postLoginUseCase: SetLoginUseCaseProtocol
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    
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

    /// Performs complete login with automatic rollback if local storage fails.
    /// This is the recommended method for login flow.
    func performCompleteLogin(authResult: ASAuthorization) async throws {
        _ = try await self.postLoginUseCase.performCompleteLogin(authResult: authResult)
    }
    
    func handleLoginFailure(error: Error) async {
        Logger.login.debug("Login failed: \(error)")
        self.crashLogger.reportToCrashlytics(error: error)
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


