//
//  GetSplashUseCase.swift
//  SplashUseCases
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import MusicRepository
import SpotifyService
import HomeRepository
import LoginRepository
import SwiftDataManager
import LoginUseCases
import CoreApp
import Models
import Analytics
import OSLog
import AuthenticationServices

public protocol GetSplashUseCaseProtocol: Sendable {
    func getCachedSections() async throws -> [HomeSection]
    func fetchHomeSections() async throws -> [HomeSection]
    func authorizeMusicKit() async -> Bool
    func isMusicKitAuthorizationDetermined() async -> Bool
    func hydrateMainMusicPlayer() async -> Bool
    func verifySpotifyConnection() async -> SpotifyConnectionState
    func reconnectSpotify() async throws -> Bool
    func cacheSections(_ sections: [HomeSection]) async throws
    func isCacheValid() async -> Bool
    func isUserLoggedIn() async -> Bool
    func areCredentialsValid() async -> Bool
    func logout() async throws
    func getCurrentNonce() async -> String
    func deleteAccount(authResult: ASAuthorization) async throws
}

public actor GetSplashUseCase: GetSplashUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol
    private let homeRepository: HomeRepositoryProtocol
    private let loginRepository: LoginRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let keychainManager: KeychainManager
    private let sessionManager: SessionManager
    private let musicPlayerManager: MusicPlayerManager
    private let userDefaultsManager: UserDefaultsManager

    public init(
        musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
        homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
        loginRepository: LoginRepositoryProtocol = LoginRepository.shared,
        swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared,
        getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
        sessionManager: SessionManager = .shared,
        musicPlayerManager: MusicPlayerManager = .shared,
        userDefaultsManager: UserDefaultsManager = .shared,
        keychainManager: KeychainManager = .shared
    ) {
        self.musicRepository = musicRepository
        self.homeRepository = homeRepository
        self.loginRepository = loginRepository
        self.swiftDataManager = swiftDataManager
        self.getLoginUseCase = getLoginUseCase
        self.keychainManager = keychainManager
        self.sessionManager = sessionManager
        self.musicPlayerManager = musicPlayerManager
        self.userDefaultsManager = userDefaultsManager
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

    public func isMusicKitAuthorizationDetermined() async -> Bool {
        await musicRepository.isMusicKitAuthorizationDetermined()
    }

    public func verifySpotifyConnection() async -> SpotifyConnectionState {
        await musicRepository.verifySpotifyConnection()
    }

    public func reconnectSpotify() async throws -> Bool {
        let authResult = try await musicRepository.requestSpotifyAuthorization()
        guard await authResult.isAuthorized else { return false }

        guard let userId = try await swiftDataManager.getCurrentUserId() else {
            return false
        }

        let isPremium = await authResult.hasSpotifyPremium
        let existingProfile = try await getLoginUseCase.getUserProfile(userId: userId)
        let updatedProfile = FirebaseUserProfile(
            email: existingProfile?.email,
            firstName: existingProfile?.firstName,
            lastName: existingProfile?.lastName,
            hasAppleMusicSubscription: existingProfile?.hasAppleMusicSubscription,
            hasSpotifyConnection: true,
            hasSpotifyPremium: isPremium,
            mainMusicPlayer: existingProfile?.mainMusicPlayer
        )
        try await loginRepository.saveUserProfile(userId: userId, profile: updatedProfile)
        return true
    }

    public func hydrateMainMusicPlayer() async -> Bool {
        let userId: String
        do {
            guard let id = try await swiftDataManager.getCurrentUserId() else { return false }
            userId = id
        } catch {
            return false
        }

        if userDefaultsManager.mainMusicPlayer(for: userId) != nil {
            await musicPlayerManager.hydrate(for: userId)
            return true
        }

        // Local cache is empty — consult the Firebase profile.
        let profile: FirebaseUserProfile?
        do {
            profile = try await getLoginUseCase.getUserProfile(userId: userId)
        } catch {
            // Transient failure (e.g. cold-launch network blip). Don't bounce the user
            // into the picker — they may have a saved choice in Firebase we just can't
            // reach right now. Treat as "already picked"; next launch will retry.
            Logger.splash.warning("hydrateMainMusicPlayer: profile fetch failed (\(error)); skipping picker")
            return true
        }

        guard let raw = profile?.mainMusicPlayer,
              let player = Models.MusicPlayer(rawValue: raw) else {
            return false
        }

        await musicPlayerManager.set(player, for: userId)
        return true
    }
    
    public func cacheSections(_ sections: [HomeSection]) async throws {
        try await swiftDataManager.cacheSections(sections)
    }
    
    public func isCacheValid() async -> Bool {
        return await swiftDataManager.isCacheValid()
    }
    
    /// Authoritative login state, read straight from local storage.
    ///
    /// Splash needs this rather than the mirrored `SessionManager.isLoggedIn`,
    /// because splash's own `.task` races `AppDataModel.checkInitialLoginStatus()`
    /// on cold launch and would otherwise see a stale `false` for a signed-in user.
    public func isUserLoggedIn() async -> Bool {
        return await swiftDataManager.isUserLoggedIn()
    }

    public func areCredentialsValid() async -> Bool {
        do {
            if try await checkUserCredentials() {
                return true
            } else {
                await forceLogout()
                return false
            }
        } catch {
            await forceLogout()
            return false
        }
    }

    /// Logs the user out after their Apple credentials turn out to be gone.
    ///
    /// This is not user-initiated, but it has to tear down exactly as much as
    /// `logout()` does — a partial version left the Firebase session live and, more
    /// visibly, left `MusicPlayerManager.current` holding the departing user's
    /// player, so the next account silently inherited it and never saw the
    /// onboarding picker. Delegate rather than maintain a second logout path.
    ///
    /// The error is absorbed rather than propagated — `areCredentialsValid()` answers
    /// `false` either way and there's no user action to offer — but it must be logged.
    /// A silent failure here leaves a half-torn-down session (Firebase still signed in,
    /// Keychain entries alive) with nothing in the logs to explain it.
    private func forceLogout() async {
        do {
            try await logout()
        } catch {
            Logger.splash.error("Forced logout after credential revocation failed: \(error)")
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

    public func getCurrentNonce() async -> String {
        await loginRepository.getCurrentNonce()
    }

    /// Deletes the account remotely (Apple token revoke + Firebase user + RTDB
    /// data) then reuses `logout()` for the identical local teardown.
    public func deleteAccount(authResult: ASAuthorization) async throws {
        // Without a userId nothing can be deleted remotely — fail loudly instead
        // of logging out and reporting a deletion that never happened.
        guard let userId: String = (try? await swiftDataManager.getCurrentUserId()) ?? nil else {
            Logger.splash.error("Account deletion attempted with no current user id")
            throw LoginError.wrongData
        }
        try await loginRepository.deleteAccount(userId: userId, authResult: authResult)
        try await logout()
    }

    public func logout() async throws {
        // Flag the intent before the state change lands, so the Account tab
        // doesn't auto-raise the sign-in sheet the moment we drop to guest.
        await sessionManager.userDidLogout()
        // Capture the current userId BEFORE wiping local storage, so we can clear
        // their per-user UserDefaults entries below. `try?` on a throwing call that
        // returns `String?` produces `String??` — collapse to `String?` with `?? nil`.
        let userId: String? = (try? await swiftDataManager.getCurrentUserId()) ?? nil

        // Step 1: Sign out from Firebase
        try await loginRepository.signOut()

        // Step 2: Clear the Keychain
        try await keychainManager.deleteAppleUserID()
        try await keychainManager.deleteSpotifyAccessToken()
        try await keychainManager.deleteSpotifyRefreshToken()

        // Step 3: Invalidate cached user ID in HomeRepository
        await homeRepository.invalidateUserCache()

        // Step 4: Set user as logged out in local storage
        try await swiftDataManager.setUserLoggedOut()

        // Step 5: Clear the main music player flag for this user.
        if let userId {
            userDefaultsManager.removeMainMusicPlayer(for: userId)
            await musicPlayerManager.clear(for: userId)
        }
    }
}

