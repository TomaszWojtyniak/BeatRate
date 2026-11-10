import Analytics
import CoreApp
import Foundation
import Models
import SpotifyService
import Testing
@testable import Splash

@MainActor
struct SplashDataModelTests {
    private let useCase = StubSplashUseCase()
    private let player = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: UserDefaults(suiteName: "SplashTests.\(UUID())")!))
    private let backend: StubAnalyticsBackend
    private let model: SplashDataModel

    private static let sections = [HomeSection(name: "New", albums: [])]

    init() {
        let analytics: AnalyticsManager
        (analytics, backend) = makeAnalytics()
        model = SplashDataModel(getSplashUseCase: useCase, musicPlayerManager: player, analyticsManager: analytics, retryDelay: .zero)
    }

    // A guest has no Apple ID; checking would read as revoked and wipe the cache every launch.
    @Test func `guest launch skips the credential check`() async {
        useCase.fetchResults = [.success(Self.sections)]

        await model.loadInitialData()

        #expect(useCase.credentialChecks == 0)
        #expect(useCase.musicKitAuthorizationRequests == 1)
        #expect(model.shouldComplete)
    }

    @Test func `revoked credentials end the launch before anything loads`() async {
        useCase.loggedIn = true
        useCase.credentialsValid = false

        await model.loadInitialData()

        #expect(useCase.musicKitAuthorizationRequests == 0)
        #expect(useCase.fetchCount == 0)
        #expect(model.shouldComplete)
    }

    @Test func `valid credentials carry on loading`() async {
        useCase.loggedIn = true
        useCase.fetchResults = [.success(Self.sections)]

        await model.loadInitialData()

        #expect(useCase.credentialChecks == 1)
        #expect(useCase.fetchCount == 1)
    }

    @Test func `undecided music access shows the explainer and waits`() async {
        useCase.authorizationDetermined = false

        await model.loadInitialData()

        #expect(model.showsMusicKitExplainer)
        #expect(!model.shouldComplete)
        #expect(useCase.musicKitAuthorizationRequests == 0)
    }

    @Test func `continuing past the explainer asks for access and finishes`() async {
        useCase.authorizationDetermined = false
        useCase.fetchResults = [.success(Self.sections)]
        await model.loadInitialData()

        await model.continueAfterExplainer()

        #expect(!model.showsMusicKitExplainer)
        #expect(model.shouldComplete)
        #expect(useCase.musicKitAuthorizationRequests == 1)
    }

    // Holding a refusing user on splash would leave them no way into the app (App Review 5.1.1).
    @Test func `refused music access still enters the app`() async {
        useCase.musicKitAuthorized = false
        useCase.fetchResults = [.success(Self.sections)]

        await model.loadInitialData()

        #expect(model.shouldComplete)
        #expect(useCase.fetchCount == 1)
    }

    @Test func `spotify users get their premium status refreshed when connected`() async {
        player.set(.spotify, for: "u")
        useCase.spotifyConnection = .connected(premium: .free)

        await model.loadInitialData()

        #expect(useCase.refreshedPremium == [.free])
    }

    // A network blip is not a logout; launch must never block on Spotify.
    @Test(arguments: [SpotifyConnectionState.unavailable, .notAllowlisted, .notConnected, .needsReauth])
    func `spotify trouble never blocks launch`(state: SpotifyConnectionState) async {
        player.set(.spotify, for: "u")
        useCase.spotifyConnection = state
        useCase.fetchResults = [.success(Self.sections)]

        await model.loadInitialData()

        #expect(useCase.refreshedPremium.isEmpty)
        #expect(useCase.fetchCount == 1)
        #expect(model.shouldComplete)
    }

    @Test func `valid cache with sections skips the network`() async {
        useCase.cacheValid = true
        useCase.cachedSections = .success(Self.sections)

        await model.loadInitialData()

        #expect(useCase.fetchCount == 0)
    }

    @Test(arguments: [false, true])
    func `empty or unreadable cache falls back to the network`(unreadable: Bool) async {
        useCase.cacheValid = true
        useCase.cachedSections = unreadable ? .failure(StubError()) : .success([])
        useCase.fetchResults = [.success(Self.sections)]

        await model.loadInitialData()

        #expect(useCase.fetchCount == 1)
        #expect(useCase.cachedSectionWrites.count == 1)
    }

    @Test func `failed cache write does not stop the launch`() async {
        useCase.fetchResults = [.success(Self.sections)]
        useCase.failsToCache = true

        await model.loadInitialData()

        #expect(model.shouldComplete)
        #expect(!model.isRetrying)
    }

    @Test func `failed fetch recovers on a retry`() async {
        useCase.fetchResults = [.failure(StubError()), .success(Self.sections)]

        await model.loadInitialData()

        #expect(useCase.fetchCount == 2)
        #expect(model.isRetrying)
        #expect(useCase.cachedSectionWrites.count == 1)
    }

    // A splash the user cannot leave is worse than an empty Home with its own retry.
    @Test(arguments: [Result<[HomeSection], StubError>.failure(StubError()), .success([])])
    func `three failed retries still enter the app`(result: Result<[HomeSection], StubError>) async {
        useCase.fetchResults = [result]
        let initialMessage = model.errorMessage

        await model.loadInitialData()

        #expect(useCase.fetchCount == 4)
        #expect(model.shouldComplete)
        #expect(model.errorMessage != initialMessage)
    }

    @Test func `screen events are tracked`() {
        model.track(.screenView(.splash))

        #expect(backend.logged(.screenView(.splash)))
    }
}
