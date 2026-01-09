//
//  PostLoginUseCase.swift
//  LoginUseCases
//
//  Created by Tomasz Wojtyniak on 11/06/2025.
//

import SwiftUI
import LoginRepository
import AuthenticationServices
import SwiftDataManager
import OSLog
import Analytics

public enum LoginUseCaseError: Error, LocalizedError {
    case localStorageFailed
    case authenticationFailed

    public var errorDescription: String? {
        switch self {
        case .localStorageFailed:
            return "Failed to save login state locally. Please try again."
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        }
    }
}

public protocol SetLoginUseCaseProtocol: Sendable {
    func performCompleteLogin(authResult: ASAuthorization) async throws -> String
}

public actor SetLoginUseCase: SetLoginUseCaseProtocol {
    private let loginRepository: LoginRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    
    public init(loginRepository: LoginRepositoryProtocol = LoginRepository.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.loginRepository = loginRepository
        self.swiftDataManager = swiftDataManager
    }

    /// Performs a complete login with transaction-like rollback support.
    /// If Firebase auth succeeds but local storage fails, Firebase auth is rolled back.
    public func performCompleteLogin(authResult: ASAuthorization) async throws -> String {
        Logger.loginUseCases.info("Starting complete login flow with rollback support")

        // Step 1: Authenticate with Firebase and save to Keychain
        let userId: String
        do {
            userId = try await loginRepository.setLoginData(authResult: authResult)
            Logger.loginUseCases.info("Firebase authentication successful for user: \(userId)")
        } catch {
            Logger.loginUseCases.error("Firebase authentication failed: \(error.localizedDescription)")
            throw LoginUseCaseError.authenticationFailed
        }

        // Step 2: Save login state locally (SwiftData)
        // This is the critical step - if it fails, we need to rollback Firebase auth
        do {
            try await self.swiftDataManager.setUserLoggedIn(userId: userId)
            Logger.loginUseCases.info("Local storage successful - login complete")
            return userId
        } catch {
            // CRITICAL: Local storage failed - rollback Firebase authentication
            Logger.loginUseCases.error("Local storage failed: \(error.localizedDescription)")
            Logger.loginUseCases.warning("Rolling back Firebase authentication due to local storage failure")

            do {
                try await loginRepository.signOut()
                Logger.loginUseCases.info("Successfully rolled back Firebase authentication")
            } catch {
                Logger.loginUseCases.error("Failed to rollback Firebase auth: \(error.localizedDescription)")
                // Continue to throw the original error even if rollback fails
            }

            throw LoginUseCaseError.localStorageFailed
        }
    }
}
