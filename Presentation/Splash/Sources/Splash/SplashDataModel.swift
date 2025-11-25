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

@Observable
@MainActor
final class SplashDataModel {
    private let getSplashUseCase: GetSplashUseCaseProtocol

    var showError: Bool = false
    var errorMessage: String = "Unable to load data. Retrying..."
    var isRetrying: Bool = false

    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    private let retryDelaySeconds: Int = 2
    private let successDelayMilliseconds: Int = 600

    init(getSplashUseCase: GetSplashUseCaseProtocol = GetSplashUseCase()) {
        self.getSplashUseCase = getSplashUseCase
    }

    // MARK: - Public Interface

    func loadInitialData() async {
        // Step 1: Validate user credentials
        guard await validateCredentials() else {
            return
        }

        // Step 2: Try to load from cache
        if await loadFromCache() {
            return
        }

        // Step 3: Fetch fresh data with retry logic
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
            // AsyncStream will trigger navigation to LoginView
            // Give time for state to propagate before allowing onComplete() to be called
            await delayForStateTransition()
            return false
        }
    }

    // MARK: - Cache Handling

    private func loadFromCache() async -> Bool {
        if await isCacheValid() {
            Logger.splash.info("Cache is valid, using cached data")
            await delayForSuccess()
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
            await delayForSuccess()
        } catch {
            // Caching failed but we have the data - proceed anyway
            Logger.splash.error("Failed to cache sections: \(error.localizedDescription). Proceeding anyway.")
            await delayForSuccess()
        }
    }

    // MARK: - Retry Logic

    private func shouldRetry() -> Bool {
        return retryCount < maxRetries
    }

    private func performRetry(reason: String) async {
        retryCount += 1
        isRetrying = true
        errorMessage = "\(reason). Retrying (\(retryCount)/\(maxRetries))..."
        Logger.splash.info("Retry attempt \(self.retryCount) of \(self.maxRetries): \(reason)")

        await delayForRetry()
        await fetchFreshData()
    }

    private func handleMaxRetriesReached(errorType: String, userMessage: String) async {
        Logger.splash.error("Max retries reached, \(errorType). Proceeding anyway.")
        errorMessage = userMessage
        showError = true

        // Brief delay to show error message, then proceed to app
        await delayForError()
        // After this delay, onComplete() will be called and user proceeds to main app
    }

    // MARK: - Delay Helpers

    private func delayForStateTransition() async {
        try? await Task.sleep(for: .milliseconds(300))
    }

    private func delayForSuccess() async {
        try? await Task.sleep(for: .milliseconds(successDelayMilliseconds))
    }

    private func delayForRetry() async {
        try? await Task.sleep(for: .seconds(retryDelaySeconds))
    }

    private func delayForError() async {
        try? await Task.sleep(for: .seconds(2))
    }
}
