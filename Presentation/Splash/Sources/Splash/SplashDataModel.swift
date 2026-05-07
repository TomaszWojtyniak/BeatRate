//
//  SplashDataModel.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import SplashUseCases
import Analytics
import OSLog
import Models
import CoreApp

@Observable
@MainActor
final class SplashDataModel {
    private let getSplashUseCase: GetSplashUseCaseProtocol

    var alertType: AlertType? = nil
    var errorMessage: String = "Unable to load data. Retrying..."
    var shouldComplete: Bool = true  // Controls whether onComplete() should be called
    /// True when MusicKit auth is `.notDetermined` and the explainer should be shown
    /// before triggering the system permission prompt.
    var showsMusicKitExplainer: Bool = false
    /// True when the user is logged in but hasn't picked a main music player yet.
    /// Read by `AppView` to present the onboarding picker before the TabBar.
    var needsMusicPlayerSelection: Bool = false

    private var retryCount: Int = 0
    private let maxRetries: Int = 3

    var isRetrying: Bool {
        retryCount > 0
    }

    init(getSplashUseCase: GetSplashUseCaseProtocol = GetSplashUseCase()) {
        self.getSplashUseCase = getSplashUseCase
    }

    // MARK: - Public Interface

    func logout() async {
        do {
            try await getSplashUseCase.logout()
            Logger.splash.info("User logged out successfully")
        } catch {
            Logger.splash.error("Logout failed: \(error.localizedDescription)")
            // Even if logout fails, we still want to proceed to login screen
            // The login screen will handle re-authentication
        }
    }

    func retryAfterSettingsChange() async {
        // Reset state for retry
        shouldComplete = true
        alertType = nil
        retryCount = 0
        showsMusicKitExplainer = false

        // Retry the full initialization
        await loadInitialData()
    }

    func loadInitialData() async {
        // Step 1: Validate user credentials
        guard await validateCredentials() else {
            return
        }

        // Step 2a: If MusicKit auth status is .notDetermined, show the in-app explainer
        // first. Splash will stop here and wait for the explainer's CTA, which calls
        // continueAfterExplainer().
        let determined = await getSplashUseCase.isMusicKitAuthorizationDetermined()
        if !determined {
            Logger.splash.info("MusicKit status notDetermined — showing explainer")
            shouldComplete = false
            showsMusicKitExplainer = true
            return
        }

        await continueAfterMusicKitGate()
    }

    /// Called by the explainer screen's CTA (or directly when status was already determined).
    func continueAfterExplainer() async {
        showsMusicKitExplainer = false
        shouldComplete = true
        await continueAfterMusicKitGate()
    }

    private func continueAfterMusicKitGate() async {
        // Step 2b: Request MusicKit authorization (MANDATORY - app cannot function without it)
        guard await requestMusicKitAuthorization() else {
            // MusicKit denied - show error and STAY on splash screen
            Logger.splash.error("MusicKit authorization denied - app cannot function")
            errorMessage = "BeatRate requires access to Apple Music to discover and rate albums."
            alertType = .musicKitDenied
            shouldComplete = false
            return
        }

        // Step 3: Hydrate the main-music-player flag (UserDefaults → Firebase fallback).
        let hasPicked = await getSplashUseCase.hydrateMainMusicPlayer()
        needsMusicPlayerSelection = !hasPicked
        Logger.splash.info("Main music player hydrated. Needs selection: \(self.needsMusicPlayerSelection)")

        // Step 4: If main player is Spotify, verify the saved token still works. If it
        // was revoked or refresh failed, surface a reconnect alert so the user can fix
        // it instantly. Skip the check otherwise.
        if MusicPlayerManager.shared.current == .spotify {
            let state = await getSplashUseCase.verifySpotifyConnection()
            switch state {
            case .connected:
                Logger.splash.info("Spotify connection verified")
            case .notConnected, .invalid:
                Logger.splash.error("Spotify connection broken: \(String(describing: state)) — prompting reconnect")
                alertType = .spotifyReconnect
                shouldComplete = false
                return
            }
        }

        // Step 5: Try to load from cache
        if await loadFromCache() {
            return
        }

        // Step 6: Fetch fresh data with retry logic
        await fetchFreshData()
    }

    func reconnectSpotify() async -> Bool {
        do {
            let success = try await getSplashUseCase.reconnectSpotify()
            if success {
                Logger.splash.info("Spotify reconnect succeeded")
                shouldComplete = true
                alertType = nil
                if await loadFromCache() {
                    return true
                }
                await fetchFreshData()
                return true
            } else {
                Logger.splash.info("Spotify reconnect cancelled or denied")
                return false
            }
        } catch {
            Logger.splash.error("Spotify reconnect failed: \(error)")
            return false
        }
    }

    /// Skip the Spotify reconnect prompt — user proceeds without a working Spotify token.
    /// They can still use the app; the play button on Album Details will gracefully hide
    /// when no Spotify URL can be resolved.
    func skipSpotifyReconnect() async {
        alertType = nil
        shouldComplete = true
        if await loadFromCache() {
            return
        }
        await fetchFreshData()
    }

    // MARK: - Credential Validation

    private func validateCredentials() async -> Bool {
        if await getSplashUseCase.areCredentialsValid() {
            Logger.splash.info("User credentials are valid")
            return true
        } else {
            Logger.splash.info("User credentials invalid or not logged in")
            // Credentials invalid - setUserLoggedOut() was called in use case
            // AsyncStream will trigger navigation to LoginView automatically
            // We DO want onComplete() to be called so navigation can happen
            return false
        }
    }

    // MARK: - MusicKit Authorization

    private func requestMusicKitAuthorization() async -> Bool {
        Logger.splash.info("Requesting MusicKit authorization")

        let isAuthorized = await getSplashUseCase.authorizeMusicKit()

        if isAuthorized {
            Logger.splash.info("MusicKit authorization granted")
            return true
        } else {
            Logger.splash.error("MusicKit authorization was not granted")
            // The error message is already set in loadInitialData() when this returns false
            return false
        }
    }

    // MARK: - Cache Handling

    private func loadFromCache() async -> Bool {
        if await isCacheValid() {
            Logger.splash.info("Cache is valid, using cached data")
            return true
        }
        Logger.splash.info("Cache not valid, will fetch fresh data")
        return false
    }

    private func isCacheValid() async -> Bool {
        // Check if cache exists and is still valid (less than 24 hours old)
        guard await getSplashUseCase.isCacheValid() else {
            Logger.splash.info("Cache is not valid or expired")
            return false
        }

        Logger.splash.info("Cache validity check passed")

        do {
            let cachedSections = try await getSplashUseCase.getCachedSections()
            if !cachedSections.isEmpty {
                Logger.splash.info("Cache has \(cachedSections.count) sections")
                return true
            } else {
                Logger.splash.info("Cache is empty")
                return false
            }
        } catch {
            // Cache read error - treat as cache miss and fetch fresh data
            Logger.splash.error("Error reading cache: \(error.localizedDescription). Will fetch fresh data.")
            return false
        }
    }

    // MARK: - Fresh Data Fetching

    private func fetchFreshData() async {
        do {
            let sections = try await getSplashUseCase.fetchHomeSections()
            Logger.splash.info("Data fetched successfully, \(sections.count) sections")

            if sections.isEmpty {
                await handleEmptySections()
            } else {
                await cacheAndComplete(sections: sections)
            }
        } catch {
            await handleFetchError(error)
        }
    }

    private func handleEmptySections() async {
        Logger.splash.warning("Fetched sections are empty")

        if shouldRetry() {
            await performRetry(reason: "No data available")
        } else {
            await handleMaxRetriesReached(
                errorType: "sections still empty",
                userMessage: "Unable to load music data. Please try again later."
            )
        }
    }

    private func handleFetchError(_ error: Error) async {
        Logger.splash.error("Error fetching data: \(error.localizedDescription)")

        if shouldRetry() {
            await performRetry(reason: "Connection error")
        } else {
            await handleMaxRetriesReached(
                errorType: "network failure",
                userMessage: "Unable to connect. Please check your connection and try again later."
            )
        }
    }

    private func cacheAndComplete(sections: [HomeSection]) async {
        do {
            Logger.splash.info("Caching \(sections.count) sections")
            try await getSplashUseCase.cacheSections(sections)
            Logger.splash.info("Data cached successfully")
        } catch {
            // Caching failed but we have the data - proceed anyway
            Logger.splash.error("Failed to cache sections: \(error.localizedDescription). Proceeding anyway.")
        }
    }

    // MARK: - Retry Logic

    private func shouldRetry() -> Bool {
        return retryCount < maxRetries
    }

    private func performRetry(reason: String) async {
        retryCount += 1
        errorMessage = "\(reason). Retrying (\(retryCount)/\(maxRetries))..."
        Logger.splash.info("Retry attempt \(self.retryCount) of \(self.maxRetries): \(reason)")

        await delayForRetry()
        await fetchFreshData()
    }

    private func handleMaxRetriesReached(errorType: String, userMessage: String) async {
        Logger.splash.error("Max retries reached, \(errorType). Showing error to user.")
        errorMessage = userMessage
        alertType = .connectionError
        shouldComplete = false  // Stay on splash screen to allow user to retry

        // Don't automatically logout - let the user decide what to do
        // The user can manually retry or choose to logout from settings
    }

    // MARK: - Delay Helpers

    private func delayForRetry() async {
        try? await Task.sleep(for: .seconds(2))
    }
}
