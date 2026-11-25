//
//  SplashViewModel.swift
//  Splash
//

import Analytics
import CoreApp
import Foundation
import Models
import Observation
import OSLog
import SplashUseCases

/// The launch: credentials, the Apple Music explainer, the player, Spotify, the cache,
/// then the sections, with three retries. Every decision is made in `update`; the
/// effects only talk to the use case and report back.
@Observable
public final class SplashViewModel: ViewModel {
    public struct State: Encodable, Equatable {
        public enum Phase: String, Encodable { case loading, musicExplainer, finished }
        public enum RetryReason: String, Encodable { case noData, connectionError }
        public struct Retry: Encodable, Equatable {
            public var attempt: Int
            public var of: Int
            public var reason: RetryReason
        }

        public var phase = Phase.loading
        /// Set while the sections are being fetched again; the view says why.
        public var retry: Retry?
    }

    public enum Action {
        /// The explainer's CTA: go on to the system prompt.
        case continuePastExplainer
    }

    enum Message {
        case viewAction(Action)
        case credentialsChecked(isValid: Bool)
        case musicAccessChecked(isDetermined: Bool)
        case cacheChecked(isUsable: Bool)
        case fetched([HomeSection])
        case fetchFailed
        case cached
        case retryDue
    }

    public internal(set) var state = State()
    /// ponytail: the handle of the latest effect (M5), so tests can wait for it.
    @ObservationIgnored var pending: Task<Void, Never>?

    private let getSplash: any GetSplashUseCaseProtocol
    private let players: MusicPlayerManager
    private let analytics: AnalyticsManager
    private let retryDelay: Duration
    private let maxRetries: Int
    private let onFinish: () -> Void

    /// Starts the launch at once: without a view's lifecycle the CLI behaves like the app.
    public init(getSplash: any GetSplashUseCaseProtocol, players: MusicPlayerManager, analytics: AnalyticsManager,
         retryDelay: Duration, maxRetries: Int = 3, onFinish: @escaping () -> Void) {
        self.getSplash = getSplash
        self.players = players
        self.analytics = analytics
        self.retryDelay = retryDelay
        self.maxRetries = maxRetries
        self.onFinish = onFinish
        analytics.log(.screenView(.splash))
        checkCredentials()
    }

    public func send(action: Action) { send(message: .viewAction(action)) }

    func update(state: inout State, message: Message) {
        guard state.phase != .finished else { return }
        switch message {
        case .credentialsChecked(isValid: false):
            // forceLogout() already ran in the use case; the login stream drops the app to guest mode.
            finish(&state)
        case .credentialsChecked(isValid: true):
            effect { .musicAccessChecked(isDetermined: await self.getSplash.isMusicKitAuthorizationDetermined()) }
        case .musicAccessChecked(isDetermined: false):
            Logger.splash.info("MusicKit status notDetermined — showing explainer")
            state.phase = .musicExplainer
            analytics.log(.screenView(.musicLibraryPermission))
        case .musicAccessChecked(isDetermined: true):
            effect { .cacheChecked(isUsable: await self.prepare()) }
        case .viewAction(.continuePastExplainer):
            guard state.phase == .musicExplainer else { return }
            analytics.log(.permissionContinueTap)
            state.phase = .loading
            effect { .cacheChecked(isUsable: await self.prepare()) }
        case .cacheChecked(isUsable: true):
            Logger.splash.info("Cache is valid, using cached data")
            finish(&state)
        case .cacheChecked(isUsable: false):
            Logger.splash.info("Cache not valid, will fetch fresh data")
            fetch()
        case .retryDue:
            fetch()
        case .fetched(let sections) where sections.isEmpty:
            Logger.splash.warning("Fetched sections are empty")
            retryOrFinish(&state, reason: .noData)
        case .fetched(let sections):
            effect {
                do {
                    Logger.splash.info("Caching \(sections.count) sections")
                    try await self.getSplash.cacheSections(sections)
                    Logger.splash.info("Data cached successfully")
                } catch {
                    // Caching failed but we have the data - proceed anyway.
                    Logger.splash.error("Failed to cache sections: \(error.localizedDescription). Proceeding anyway.")
                }
                return .cached
            }
        case .fetchFailed:
            retryOrFinish(&state, reason: .connectionError)
        case .cached:
            finish(&state)
        }
    }

    /// Runs `work` and sends what it returns; the handle is kept so tests can wait on it.
    private func effect(_ work: @escaping () async -> Message) {
        pending = Task { send(message: await work()) }
    }

    private func checkCredentials() {
        // Signed-in users only. A guest has no Apple user ID in the Keychain, so
        // `areCredentialsValid()` would treat that as a revoked login and call
        // `setUserLoggedOut()`, wiping the cached sections/albums on every launch.
        effect {
            guard await self.getSplash.isUserLoggedIn() else { return .credentialsChecked(isValid: true) }
            let isValid = await self.getSplash.areCredentialsValid()
            Logger.splash.info("User credentials \(isValid ? "valid" : "invalid or not logged in")")
            return .credentialsChecked(isValid: isValid)
        }
    }

    /// Steps 2b–4 of the launch, then whether the cache can stand in for a fetch.
    private func prepare() async -> Bool {
        // A refusal is not fatal: `TabBarView` explains it and links to Settings.
        // Holding the user here leaves them no route into the app at all — an App
        // Review rejection under 5.1.1, and a dead end for guests.
        Logger.splash.info("Requesting MusicKit authorization")
        if await getSplash.authorizeMusicKit() {
            Logger.splash.info("MusicKit authorization granted")
        } else {
            CrashLogger.report("Connect.appleMusic", "splash: authorization not granted", to: .splash)
            Logger.splash.notice("MusicKit not authorized — continuing in reduced mode")
        }

        // `AppView` decides whether to show the picker from `MusicPlayerManager.current`,
        // which this hydration populates.
        let hasPicked = await getSplash.hydrateMainMusicPlayer()
        Logger.splash.info("Main music player hydrated. Needs selection: \(!hasPicked)")

        // Check the saved Spotify session for telemetry and premium freshness — but never
        // block launch and never prompt here. A network blip is not a logout. Re-auth lives in Settings.
        if players.current == .spotify {
            switch await getSplash.verifySpotifyConnection() {
            case .connected(let premium):
                Logger.splash.info("Spotify connection verified")
                await getSplash.refreshSpotifyPremium(premium)
            case .unavailable:
                Logger.splash.info("Spotify unreachable right now — continuing, session left intact")
            case .notAllowlisted:
                Logger.splash.error("Spotify account not on the Development Mode allowlist — continuing")
            case .notConnected, .needsReauth:
                Logger.splash.info("Spotify session needs attention — surfaced in Settings, launch continues")
            }
        }

        guard await getSplash.isCacheValid() else {
            Logger.splash.info("Cache is not valid or expired")
            return false
        }
        Logger.splash.info("Cache validity check passed")
        do {
            let cached = try await getSplash.getCachedSections()
            if cached.isEmpty {
                Logger.splash.info("Cache is empty")
            } else {
                Logger.splash.info("Cache has \(cached.count) sections")
            }
            return !cached.isEmpty
        } catch {
            Logger.splash.error("Error reading cache: \(error.localizedDescription). Will fetch fresh data.")
            return false
        }
    }

    private func fetch() {
        effect {
            do {
                let sections = try await self.getSplash.fetchHomeSections()
                Logger.splash.info("Data fetched successfully, \(sections.count) sections")
                return .fetched(sections)
            } catch {
                CrashLogger.log("Error fetching data: \(error.localizedDescription)", to: .splash)
                return .fetchFailed
            }
        }
    }

    private func retryOrFinish(_ state: inout State, reason: State.RetryReason) {
        let attempt = (state.retry?.attempt ?? 0) + 1
        guard attempt <= maxRetries else {
            // Enter the app anyway. Home renders the failure with its own retry, and a
            // splash screen the user cannot leave is worse than an empty one they can.
            // Only the final failure is reported: the retries before it are expected noise offline.
            if reason == .connectionError { CrashLogger.report("SplashFetch", "fetch failed \(maxRetries + 1) times") }
            CrashLogger.log("Max retries reached, \(reason.exhausted). Entering the app so Home can recover.", to: .splash)
            finish(&state)
            return
        }
        state.retry = State.Retry(attempt: attempt, of: maxRetries, reason: reason)
        Logger.splash.info("Retry attempt \(attempt) of \(self.maxRetries): \(reason.logText)")
        effect { [retryDelay] in
            try? await Task.sleep(for: retryDelay)
            return .retryDue
        }
    }

    private func finish(_ state: inout State) {
        state.phase = .finished
        state.retry = nil
        // After `update` returns, like any effect: the root redraws on this, and the
        // redraw reads `state`, which is still being written until then.
        pending = Task { [onFinish] in onFinish() }
    }
}

private extension SplashViewModel.State.RetryReason {
    /// The breadcrumbs' wording from before the migration, so Crashlytics logs read the same.
    var logText: String { self == .noData ? "No data available" : "Connection error" }
    var exhausted: String { self == .noData ? "sections still empty" : "network failure" }
}
