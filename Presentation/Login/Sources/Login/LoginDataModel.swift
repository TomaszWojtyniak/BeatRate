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
    var errorTitle: String = "Sign In Failed"
    var errorMessage: String = "An error occurred. Please try again."
    var isLoading: Bool = false
    
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
        isLoading = true
        defer { isLoading = false }

        _ = try await self.postLoginUseCase.performCompleteLogin(authResult: authResult)
    }
    
    func handleLoginFailure(error: Error) async {
        Logger.login.debug("Login failed: \(error)")
        self.crashLogger.reportToCrashlytics(error: error)

        // Provide user-friendly error messages based on error type
        if let loginError = error as? LoginUseCaseError {
            switch loginError {
            case .localStorageFailed:
                errorTitle = "Storage Error"
                errorMessage = "Unable to save your login information. Please ensure the app has sufficient storage and try again."
            case .authenticationFailed:
                errorTitle = "Authentication Failed"
                errorMessage = "Unable to sign in with Apple. Please check your internet connection and try again."
            }
        } else if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .unknown:
                errorTitle = "Sign In Error"
                errorMessage = "An unexpected error occurred. Please try again."
            case .notHandled:
                errorTitle = "Sign In Error"
                errorMessage = "Unable to complete sign in. Please try again."
            case .failed:
                errorTitle = "Sign In Failed"
                errorMessage = "Apple Sign In failed. Please check your Apple ID settings and try again."
            default:
                errorTitle = "Sign In Error"
                errorMessage = "An error occurred during sign in. Please try again."
            }
        } else {
            // Generic error
            errorTitle = "Sign In Failed"
            errorMessage = "Unable to sign in. Please check your internet connection and try again."
        }

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


