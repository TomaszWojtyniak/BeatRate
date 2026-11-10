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
    /// Signs in with the credential from the Apple sheet; a failure shows the alert.
    func completeSignIn(authResult: ASAuthorization) async {
        do {
            try await performCompleteLogin(authResult: authResult)
        } catch {
            await reportSignInFailure(error)
        }
    }

    func completeSignIn(credential: AppleSignInCredential) async {
        do {
            try await performCompleteLogin(credential: credential)
            Logger.login.debug("Complete login successful from prompt (Firebase + local storage)")
        } catch {
            await reportSignInFailure(error)
        }
    }

    /// The Apple sheet itself failed. Cancelling is a normal outcome — the guest
    /// keeps browsing — so it is tracked but shows no error.
    func handleAuthorizationFailure(_ error: Error) async {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            analyticsManager.log(.loginFailed(errorType: "canceled"))
            Logger.login.debug("User cancelled sign in from prompt - no error shown")
            return
        }
        await handleLoginFailure(error: error)
    }

    private func reportSignInFailure(_ error: Error) async {
        CrashLogger.log("Login from prompt failed: \(error.localizedDescription)", to: .login)
        await handleLoginFailure(error: error)
    }

    func performCompleteLogin(authResult: ASAuthorization) async throws {
        guard let credential = AppleSignInCredential(authResult) else {
            throw LoginUseCaseError.authenticationFailed
        }
        try await performCompleteLogin(credential: credential)
    }

    func performCompleteLogin(credential: AppleSignInCredential) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await self.postLoginUseCase.performCompleteLogin(credential: credential)
    }
    
    func handleLoginFailure(error: Error) async {
        Logger.login.debug("Login failed: \(error)")
        self.crashLogger.reportToCrashlytics(error: error)

        // Provide user-friendly error messages based on error type
        if let loginError = error as? LoginUseCaseError {
            analyticsManager.log(.loginFailed(errorType: loginError == .localStorageFailed ? "local_storage_failed" : "authentication_failed"))
            switch loginError {
            case .localStorageFailed:
                errorTitle = String(localized: .errorStorageTitle)
                errorMessage = String(localized: .errorStorageMessage)
            case .authenticationFailed:
                errorTitle = String(localized: .errorAuthTitle)
                errorMessage = String(localized: .errorAuthMessage)
            }
        } else if let authError = error as? ASAuthorizationError {
            analyticsManager.log(.loginFailed(errorType: "apple_error"))
            switch authError.code {
            case .unknown:
                errorTitle = String(localized: .errorSignInTitle)
                errorMessage = String(localized: .errorUnexpectedMessage)
            case .notHandled:
                errorTitle = String(localized: .errorSignInTitle)
                errorMessage = String(localized: .errorIncompleteMessage)
            case .failed:
                errorTitle = String(localized: .errorSignInFailedTitle)
                errorMessage = String(localized: .errorAppleMessage)
            default:
                errorTitle = String(localized: .errorSignInTitle)
                errorMessage = String(localized: .errorUnknownMessage)
            }
        } else {
            // Generic error
            analyticsManager.log(.loginFailed(errorType: "unknown"))
            errorTitle = String(localized: .errorSignInFailedTitle)
            errorMessage = String(localized: .errorNetworkMessage)
        }

        self.isShowingErrorAlert = true
    }
    
    func getCurrentNonce() async -> String {
        await self.getLoginUseCase.getCurrentNonce()
    }
    
    func track(_ event: AnalyticsEvent) {
        analyticsManager.log(event)
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


