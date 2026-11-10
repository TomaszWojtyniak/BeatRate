import Analytics
import CoreApp
import Foundation
import Models
import SpotifyService
import Testing
@testable import Settings

@MainActor
struct SettingsDataModelTests {
    private let splash = StubSplashUseCase()
    private let settings = StubSettingsUseCase()
    private let session = SessionManager()
    private let player = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: UserDefaults(suiteName: "SettingsTests.\(UUID())")!))
    private let analytics: AnalyticsManager
    private let backend: StubAnalyticsBackend
    private let model: SettingsDataModel

    init() {
        (analytics, backend) = makeAnalytics()
        model = SettingsDataModel(getSplashUseCase: splash, getSettingsUseCase: settings, musicPlayerManager: player, analyticsManager: analytics, sessionManager: session)
    }

    @Test func `analytics toggle starts from the stored consent and saves changes`() {
        #expect(!model.isAnalyticsEnabled)

        model.isAnalyticsEnabled = true

        #expect(analytics.consent == true)
    }

    @Test func `login state and player come from the shared managers`() {
        session.update(isLoggedIn: true)
        player.set(.spotify, for: "u")

        #expect(model.isLoggedIn)
        #expect(model.mainMusicPlayer == .spotify)
    }

    @Test(arguments: [
        (SpotifyConnectionState.needsReauth, true),
        (.notConnected, true),
        (.connected(premium: .free), false),
        (.unavailable, false),
        (.notAllowlisted, false),
    ])
    func `only a dead spotify session shows the reconnect notice`(state: SpotifyConnectionState, showsNotice: Bool) async {
        settings.spotifyStatus = .success(true)
        splash.spotifyConnection = state

        await model.loadUserProfile()

        #expect(model.isSpotifyConnected)
        #expect((model.spotifyNotice != nil) == showsNotice)
    }

    @Test func `unconnected spotify shows no notice`() async {
        splash.spotifyConnection = .needsReauth

        await model.loadUserProfile()

        #expect(!model.isSpotifyConnected)
        #expect(model.spotifyNotice == nil)
    }

    @Test func `failed status read leaves spotify disconnected`() async {
        settings.spotifyStatus = .failure(StubError())

        await model.loadUserProfile()

        #expect(!model.isSpotifyConnected)
    }

    @Test func `logout is tracked when it succeeds`() async throws {
        try await model.logout()

        #expect(splash.logoutCount == 1)
        #expect(!model.isLoggingOut)
        #expect(backend.logged(.logout))
    }

    @Test func `failed logout is passed on and not tracked`() async {
        splash.failsToLogOut = true

        await #expect(throws: StubError.self) { try await model.logout() }
        #expect(!model.isLoggingOut)
        #expect(!backend.logged(.logout))
    }

    @Test func `nonce is hashed with sha256 for apple re-authentication`() async {
        #expect(await model.getCurrentNonce() == "nonce")
        #expect(model.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func `screen events are tracked`() {
        model.track(.screenView(.settings))

        #expect(backend.logged(.screenView(.settings)))
    }
}
