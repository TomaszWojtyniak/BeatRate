//
//  BeatRateDevelopmentTests.swift
//  BeatRateDevelopmentTests
//
//  Created by Tomasz Wojtyniak on 23/10/2026.
//

import Analytics
import AppUseCases
import CoreApp
import Foundation
import Models
import Synchronization
import TabBar
import Testing
@testable import BeatRate_Development

// The app folder is synchronized into the app targets, so this target's doubles
// live in this one file rather than a separate `…TestDoubles.swift`.

struct StubError: Error {}

/// Main-actor because the protocol inherits its package's default main-actor isolation.
@MainActor
final class StubAppUseCase: GetAppUseCaseProtocol {
    var user: Result<User?, StubError> = .success(nil)
    var loggedIn = false
    /// Login states the stream replays before it finishes.
    var loginStates: [Bool] = []

    func getCurrentUser() async throws -> User? { try user.get() }
    func isUserLoggedIn() async -> Bool { loggedIn }

    func observeLoginState() -> AsyncStream<Bool> {
        let states = loginStates
        return AsyncStream { continuation in
            states.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

@MainActor
final class StubAnalyticsBackend: AnalyticsBackend {
    private(set) var events: [String] = []
    private(set) var userIds: [String?] = []

    func logEvent(_ name: String, parameters: [String: Any]?) { events.append(name) }
    func setUserID(_ userId: String?) { userIds.append(userId) }
    func setConsent(analyticsGranted: Bool) {}
    func setCollectionEnabled(_ enabled: Bool) {}
    func resetData() {}
    func setUserProperty(_ value: String?, forName name: String) {}
}

final class StubCrashBackend: CrashBackend {
    private let identifiers = Mutex<[String?]>([])

    var userIds: [String?] { identifiers.withLock { $0 } }

    func setUserID(_ userId: String?) { identifiers.withLock { $0.append(userId) } }
    func setCollectionEnabled(_ enabled: Bool) {}
    func record(_ error: Error) {}
    func log(_ message: String) {}
    func setCustomValue(_ value: String, forKey key: String) {}
}

@MainActor
struct AppDataModelTests {
    private let useCase = StubAppUseCase()
    private let session = SessionManager()
    private let analyticsBackend = StubAnalyticsBackend()
    private let crashBackend = StubCrashBackend()
    private let defaults = UserDefaults(suiteName: "AppTests.\(UUID())")!
    private let analytics: AnalyticsManager
    private let player: MusicPlayerManager

    init() {
        analytics = AnalyticsManager(defaults: defaults, backend: analyticsBackend)
        player = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: defaults))
    }

    private func model() -> AppDataModel {
        AppDataModel(analyticsManager: analytics, crashLogger: CrashLogger(backend: crashBackend), sessionManager: session, musicPlayerManager: player, getAppUseCase: useCase)
    }

    // MARK: - Root screen

    @Test func `launch starts on the splash`() {
        #expect(model().rootScreen == .splash)
    }

    @Test func `guest goes straight to the tabs`() {
        let model = model()
        model.showingSplash = false

        #expect(model.rootScreen == .tabs)
    }

    @Test func `signed in user without a player picks one first`() {
        let model = model()
        model.loginStateChanged(to: true)
        model.showingSplash = false

        #expect(model.rootScreen == .playerPicker)

        player.set(.spotify, for: "u")

        #expect(model.rootScreen == .tabs)
    }

    // MARK: - Analytics consent

    @Test func `consent is asked only until the user answers`() {
        #expect(model().isAskingAnalyticsConsent)

        analytics.setConsent(false)

        #expect(!model().isAskingAnalyticsConsent)
    }

    // setUserId() at launch is a no-op while analytics is off, so granting must set it.
    @Test func `granting consent attributes the signed in user`() async {
        useCase.user = .success(User(isLoggedIn: true, userId: "u"))
        let model = model()
        await model.getCurrentUser()

        model.setAnalyticsConsent(true)

        #expect(analytics.consent == true)
        #expect(analyticsBackend.userIds == ["u"])
        #expect(crashBackend.userIds == ["u"])
    }

    @Test func `refusing consent attributes nobody`() async {
        useCase.user = .success(User(isLoggedIn: true, userId: "u"))
        let model = model()
        await model.getCurrentUser()

        model.setAnalyticsConsent(false)

        #expect(crashBackend.userIds.isEmpty)
    }

    // Plain values, not `User`s: SwiftData models are not Sendable test arguments.
    @Test(arguments: [nil, (false, "u"), (true, "")] as [(Bool, String)?])
    func `guests are never attributed`(user: (isLoggedIn: Bool, userId: String)?) async {
        useCase.user = .success(user.map { User(isLoggedIn: $0.isLoggedIn, userId: $0.userId) })
        let model = model()
        await model.getCurrentUser()

        model.setUserId()

        #expect(crashBackend.userIds.isEmpty)
    }

    @Test func `unreadable user leaves the model without one`() async {
        useCase.user = .failure(StubError())
        let model = model()

        await model.getCurrentUser()

        #expect(model.user == nil)
    }

    // MARK: - Login state

    @Test(arguments: [true, false])
    func `launch login state is mirrored into the session`(loggedIn: Bool) async {
        useCase.loggedIn = loggedIn
        let model = model()

        await model.checkInitialLoginStatus()

        #expect(model.isUserLoggedIn == loggedIn)
        #expect(session.isLoggedIn == loggedIn)
    }

    @Test func `signing in shows the splash again to load the users data`() {
        let model = model()
        model.showingSplash = false

        model.loginStateChanged(to: true)

        #expect(model.showingSplash)
        #expect(session.isLoggedIn)
    }

    @Test func `staying signed in does not replay the splash`() {
        let model = model()
        model.loginStateChanged(to: true)
        model.showingSplash = false

        model.loginStateChanged(to: true)

        #expect(!model.showingSplash)
    }

    // Logout or account deletion must stop attributing events to that user.
    @Test func `signing out clears the analytics and crash identities`() {
        let model = model()
        model.loginStateChanged(to: true)
        model.showingSplash = false

        model.loginStateChanged(to: false)

        #expect(!model.isUserLoggedIn)
        #expect(!model.showingSplash)
        #expect(crashBackend.userIds == [nil])
    }

    @Test func `every login state change is followed`() async {
        useCase.loginStates = [true, false]
        let model = model()

        await model.startObservingLoginState().value

        #expect(!model.isUserLoggedIn)
        #expect(crashBackend.userIds == [nil])
    }

    // MARK: - Login prompt and tabs

    @Test func `login prompt is driven by the session`() {
        let model = model()
        session.requestLogin(reason: .rating)

        #expect(model.isPresentingLoginPrompt)
        #expect(model.loginPromptReason == .rating)

        model.isPresentingLoginPrompt = false

        #expect(!session.isPresentingLoginPrompt)
    }

    @Test func `tab changes are tracked`() {
        analytics.setAnalyticsEnabled(true)
        let model = model()

        model.trackTabSelected(nil)
        model.trackTabSelected(.search)

        #expect(analyticsBackend.events == [AnalyticsEvent.tabSelected(tab: "search").name])
    }
}
