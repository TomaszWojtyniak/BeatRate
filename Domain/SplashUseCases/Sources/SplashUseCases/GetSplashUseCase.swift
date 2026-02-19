//
//  GetSplashUseCase.swift
//  SplashUseCases
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import MusicRepository
import HomeRepository
import LoginRepository
import SwiftDataManager
import LoginUseCases
import CoreApp
import Models
import AuthenticationServices

public protocol GetSplashUseCaseProtocol: Sendable {
    func getCachedSections() async throws -> [HomeSection]
    func fetchHomeSections() async throws -> [HomeSection]
    func authorizeMusicKit() async -> Bool
    func cacheSections(_ sections: [HomeSection]) async throws
    func isCacheValid() async -> Bool
    func areCredentialsValid() async -> Bool
    func logout() async throws
}

public actor GetSplashUseCase: GetSplashUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol
    private let homeRepository: HomeRepositoryProtocol
    private let loginRepository: LoginRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let keychainManager: KeychainManager

    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
         homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
         loginRepository: LoginRepositoryProtocol = LoginRepository.shared,
         swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared,
         getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         keychainManager: KeychainManager = .shared) {
        self.musicRepository = musicRepository
        self.homeRepository = homeRepository
        self.loginRepository = loginRepository
        self.swiftDataManager = swiftDataManager
        self.getLoginUseCase = getLoginUseCase
        self.keychainManager = keychainManager
    }
    
    public func getCachedSections() async throws -> [HomeSection] {
        return try await swiftDataManager.getCachedSections()
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        return try await homeRepository.fetchHomeSections()
    }
    
    public func authorizeMusicKit() async -> Bool {
        let result = await musicRepository.requestMusicAuthorization()
        return await result.isAuthorized
    }
    
    public func cacheSections(_ sections: [HomeSection]) async throws {
        try await swiftDataManager.cacheSections(sections)
    }
    
    public func isCacheValid() async -> Bool {
        return await swiftDataManager.isCacheValid()
    }
    
    public func areCredentialsValid() async -> Bool {
        do {
            if try await checkUserCredentials() {
                return true
            } else {
                try? await swiftDataManager.setUserLoggedOut()
                return false
            }
        } catch {
            try? await swiftDataManager.setUserLoggedOut()
            return false
        }
    }

    private func checkUserCredentials() async throws -> Bool {
        // Get Apple user ID from Keychain (not Firebase userId)
        guard let appleUserID = try await keychainManager.loadAppleUserID() else {
            // No Apple user ID in Keychain - user not logged in with Apple
            return false
        }

        let credentialState = await fetchAppleIDCredentialState(for: appleUserID)

        switch credentialState {
        case .authorized:
            // Credentials are valid
            return true
        case .revoked:
            // User revoked access
            return false
        case .notFound:
            // Credentials not found
            return false
        case .transferred:
            // Credentials transferred to another device
            return false
        @unknown default:
            // Unknown state
            return false
        }
    }
    
    private func fetchAppleIDCredentialState(for userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userId) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    public func logout() async throws {
        // Step 1: Sign out from Firebase
        try await loginRepository.signOut()

        // Step 2: Clear the Keychain
        try await keychainManager.deleteAppleUserID()

        // Step 3: Invalidate cached user ID in HomeRepository
        await homeRepository.invalidateUserCache()

        // Step 4: Set user as logged out in local storage
        try await swiftDataManager.setUserLoggedOut()
    }
}

