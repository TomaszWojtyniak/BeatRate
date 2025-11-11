//
//  GetSplashUseCase.swift
//  SplashUseCases
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import MusicRepository
import HomeRepository
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
    func checkUserCredentials() async throws -> Bool
}

public actor GetSplashUseCase: GetSplashUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol
    private let homeRepository: HomeRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let keychainManager: KeychainManager

    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
         homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
         swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared,
         getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         keychainManager: KeychainManager = .shared) {
        self.musicRepository = musicRepository
        self.homeRepository = homeRepository
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
        return await musicRepository.requestMusicAuthorization()
    }
    
    public func cacheSections(_ sections: [HomeSection]) async throws {
        try await swiftDataManager.cacheSections(sections)
    }
    
    public func isCacheValid() async -> Bool {
        return await swiftDataManager.isCacheValid()
    }

    public func checkUserCredentials() async throws -> Bool {
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
            // User revoked access - log them out and clear Keychain
            try await swiftDataManager.setUserLoggedOut()
            try await keychainManager.deleteAppleUserID()
            return false
        case .notFound:
            // Credentials not found - log them out and clear Keychain
            try await swiftDataManager.setUserLoggedOut()
            try await keychainManager.deleteAppleUserID()
            return false
        case .transferred:
            // Credentials transferred to another device - log them out and clear Keychain
            try await swiftDataManager.setUserLoggedOut()
            try await keychainManager.deleteAppleUserID()
            return false
        @unknown default:
            // Unknown state - log them out for safety and clear Keychain
            try await swiftDataManager.setUserLoggedOut()
            try await keychainManager.deleteAppleUserID()
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
}

