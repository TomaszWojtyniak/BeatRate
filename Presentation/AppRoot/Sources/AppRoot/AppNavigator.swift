//
//  AppNavigator.swift
//  AppRoot
//

import Analytics
import AppUseCases
import Composition
import CoreApp
import Foundation
import Models
import Observation
import OSLog
import Splash

/// What the app shows at its top level: the splash, the player picker or the tabs,
/// with the analytics consent alert and the login sheet over them. Owns the one
/// subscription to the login state and mirrors it into `SessionManager`.
@Observable
public final class AppNavigator: ViewModel {
    public struct State: Encodable, Equatable {
        public enum Phase: String, Encodable { case splash, playerPicker, tabs }
        public var phase = Phase.splash
        public var isShowingSplash = true
        public var isLoggedIn = false
        public var hasPlayer: Bool
        /// The signed-in user analytics and crash reports are attributed to.
        public var userId: String?
        public var isAskingAnalyticsConsent: Bool
        public var analyticsConsent: Bool?
        /// Why the login sheet is up, or nil while it is down.
        public var loginPrompt: LoginPromptReason?
    }

    public enum Action {
        case allowAnalytics
        case denyAnalytics
        /// The login sheet's close, or the sheet swiped down.
        case dismissLoginPrompt
        /// A tab picked in the legacy tab bar; only tracked until phase 3 moves tabs into Core.
        case selectedTab(String)
    }

    enum Message {
        case viewAction(Action)
        case initialLoginStatus(Bool)
        case loginStateChanged(Bool)
        case splashFinished
        case userLoaded(userId: String?)
        case playerChanged(hasPlayer: Bool)
        case loginPromptChanged(LoginPromptReason?)
    }

    public internal(set) var state: State
    /// ponytail: always set — made in `init` once `self` exists; replaced on every new launch.
    public private(set) var splash: SplashViewModel!
    /// ponytail: handles of the long-lived observations (M5); they end with the navigator.
    @ObservationIgnored private var observations: [Task<Void, Never>] = []

    private let getApp: any GetAppUseCaseProtocol
    private let session: SessionManager
    private let analytics: AnalyticsManager
    private let crashLogger: CrashLogger
    private let makeSplash: (@escaping () -> Void) -> SplashViewModel

    init(getApp: any GetAppUseCaseProtocol, session: SessionManager, players: MusicPlayerManager,
         analytics: AnalyticsManager, crashLogger: CrashLogger,
         makeSplash: @escaping (_ onFinish: @escaping () -> Void) -> SplashViewModel) {
        self.getApp = getApp
        self.session = session
        self.analytics = analytics
        self.crashLogger = crashLogger
        self.makeSplash = makeSplash
        state = State(hasPlayer: players.current != nil, isAskingAnalyticsConsent: analytics.consent == nil,
                      analyticsConsent: analytics.consent)
        startSplash()
        observations = [
            Task { [weak self, getApp] in
                let isLoggedIn = await getApp.isUserLoggedIn()
                self?.send(message: .initialLoginStatus(isLoggedIn))
                for await isLoggedIn in getApp.observeLoginState() {
                    self?.send(message: .loginStateChanged(isLoggedIn))
                }
            },
            Task { [weak self] in
                for await hasPlayer in Observations({ players.current != nil }) {
                    self?.send(message: .playerChanged(hasPlayer: hasPlayer))
                }
            },
            Task { [weak self] in
                for await reason in Observations({ session.isPresentingLoginPrompt ? session.loginPromptReason : nil }) {
                    self?.send(message: .loginPromptChanged(reason))
                }
            },
        ]
    }

    public convenience init(graph: Graph) {
        self.init(getApp: graph.getApp, session: graph.session, players: graph.players,
                  analytics: graph.analytics, crashLogger: .shared) { onFinish in
            SplashViewModel(getSplash: graph.getSplash, players: graph.players, analytics: graph.analytics,
                            retryDelay: graph.retryDelay, onFinish: onFinish)
        }
    }

    isolated deinit {
        observations.forEach { $0.cancel() }
    }

    public func send(action: Action) { send(message: .viewAction(action)) }

    func update(state: inout State, message: Message) {
        switch message {
        case .initialLoginStatus(let isLoggedIn):
            state.isLoggedIn = isLoggedIn
            session.update(isLoggedIn: isLoggedIn)
            Logger.app.debug("Initial user logged in status: \(isLoggedIn)")
        case .loginStateChanged(let isLoggedIn):
            let wasLoggedOut = !state.isLoggedIn
            state.isLoggedIn = isLoggedIn
            session.update(isLoggedIn: isLoggedIn)
            if !isLoggedIn {
                // Logout or account deletion: stop attributing events to that user.
                state.userId = nil
                analytics.setUserId(nil)
                crashLogger.setUserIdentifier(nil)
            }
            // Not while a splash runs: restoring a lost login row inside it reports a
            // login, and a second splash would check, authorize and fetch all over again.
            if isLoggedIn && wasLoggedOut && !state.isShowingSplash {
                state.isShowingSplash = true
                startSplash()
                Logger.app.debug("User logged in - showing splash screen")
            }
            Logger.app.debug("Login state changed: \(isLoggedIn)")
        case .splashFinished:
            state.isShowingSplash = false
        case .userLoaded(let userId):
            guard let userId else {
                Logger.app.debug("No user id to set - browsing as guest")
                return
            }
            state.userId = userId
            identify(userId)
        case .playerChanged(let hasPlayer):
            state.hasPlayer = hasPlayer
        case .loginPromptChanged(let reason):
            state.loginPrompt = reason
        case .viewAction(.allowAnalytics), .viewAction(.denyAnalytics):
            guard state.isAskingAnalyticsConsent else { return }
            let granted = if case .viewAction(.allowAnalytics) = message { true } else { false }
            state.isAskingAnalyticsConsent = false
            state.analyticsConsent = granted
            analytics.setConsent(granted)
            // Identifying at launch was a no-op while analytics was off.
            if granted, let userId = state.userId { identify(userId) }
        case .viewAction(.dismissLoginPrompt):
            state.loginPrompt = nil
            session.isPresentingLoginPrompt = false
        case .viewAction(.selectedTab(let tab)):
            analytics.log(.tabSelected(tab: tab))
        }
        state.phase = state.isShowingSplash ? .splash : state.isLoggedIn && !state.hasPlayer ? .playerPicker : .tabs
    }

    /// A new splash, and who the user is for analytics and crash reports.
    private func startSplash() {
        splash = makeSplash { [weak self] in self?.send(message: .splashFinished) }
        Task { [weak self, getApp] in
            var userId: String?
            do {
                if let user = try await getApp.getCurrentUser(), user.isLoggedIn, !user.userId.isEmpty {
                    userId = user.userId
                }
            } catch {
                CrashLogger.log("Cant get current user: \(error)", to: .app)
            }
            self?.send(message: .userLoaded(userId: userId))
        }
    }

    private func identify(_ userId: String) {
        analytics.setUserId(userId)
        crashLogger.setUserIdentifier(userId)
        Logger.app.debug("Set user id for crashlytics and analytics")
    }
}
