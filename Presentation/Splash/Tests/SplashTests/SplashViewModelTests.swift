import Analytics
import CoreApp
import Foundation
import IntrospectionKit
import Models
import SpotifyService
import Testing
@testable import Splash

@MainActor
struct SplashViewModelTests {
    private let useCase = StubSplashUseCase()
    private let player = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: UserDefaults(
        suiteName: FileManager.default.temporaryDirectory.appending(path: "SplashTests.\(UUID())").path)!))
    private let analytics: AnalyticsManager
    private let backend: StubAnalyticsBackend
    private let finishes = Counter()

    private static let sections = [HomeSection(name: "New", albums: [])]

    init() {
        (analytics, backend) = makeAnalytics()
    }

    /// Starts the launch, as the app does, and waits until it has nothing left to do.
    private func launch() async -> SplashViewModel {
        let viewModel = SplashViewModel(getSplash: useCase, players: player, analytics: analytics,
                                        retryDelay: .zero, onFinish: finishes.increment)
        await viewModel.settled()
        return viewModel
    }

    // A guest has no Apple ID; checking would read as revoked and wipe the cache every launch.
    @Test func `guest launch skips the credential check`() async {
        useCase.fetchResults = [.success(Self.sections)]

        let viewModel = await launch()

        #expect(useCase.credentialChecks == 0)
        #expect(useCase.musicKitAuthorizationRequests == 1)
        #expect(viewModel.state.phase == .finished)
        #expect(finishes.count == 1)
    }

    @Test func `revoked credentials end the launch before anything loads`() async {
        useCase.loggedIn = true
        useCase.credentialsValid = false

        let viewModel = await launch()

        #expect(useCase.musicKitAuthorizationRequests == 0)
        #expect(useCase.fetchCount == 0)
        #expect(viewModel.state.phase == .finished)
        #expect(finishes.count == 1)
    }

    @Test func `valid credentials carry on loading`() async {
        useCase.loggedIn = true
        useCase.fetchResults = [.success(Self.sections)]

        _ = await launch()

        #expect(useCase.credentialChecks == 1)
        #expect(useCase.fetchCount == 1)
    }

    @Test func `undecided music access shows the explainer and waits`() async {
        useCase.authorizationDetermined = false

        let viewModel = await launch()

        #expect(viewModel.state.phase == .musicExplainer)
        #expect(finishes.count == 0)
        #expect(useCase.musicKitAuthorizationRequests == 0)
        #expect(backend.logged(.screenView(.musicLibraryPermission)))
    }

    @Test func `continuing past the explainer asks for access and finishes`() async {
        useCase.authorizationDetermined = false
        useCase.fetchResults = [.success(Self.sections)]
        let viewModel = await launch()

        viewModel.send(action: .continuePastExplainer)
        #expect(viewModel.state.phase == .loading)
        await viewModel.settled()

        #expect(viewModel.state.phase == .finished)
        #expect(finishes.count == 1)
        #expect(useCase.musicKitAuthorizationRequests == 1)
        #expect(backend.logged(.permissionContinueTap))
    }

    // Holding a refusing user on splash would leave them no way into the app (App Review 5.1.1).
    @Test func `refused music access still enters the app`() async {
        useCase.musicKitAuthorized = false
        useCase.fetchResults = [.success(Self.sections)]

        let viewModel = await launch()

        #expect(viewModel.state.phase == .finished)
        #expect(useCase.fetchCount == 1)
    }

    @Test func `spotify users get their premium status refreshed when connected`() async {
        player.set(.spotify, for: "u")
        useCase.spotifyConnection = .connected(premium: .free)

        _ = await launch()

        #expect(useCase.refreshedPremium == [.free])
    }

    // A network blip is not a logout; launch must never block on Spotify.
    @Test(arguments: [SpotifyConnectionState.unavailable, .notAllowlisted, .notConnected, .needsReauth])
    func `spotify trouble never blocks launch`(state: SpotifyConnectionState) async {
        player.set(.spotify, for: "u")
        useCase.spotifyConnection = state
        useCase.fetchResults = [.success(Self.sections)]

        let viewModel = await launch()

        #expect(useCase.refreshedPremium.isEmpty)
        #expect(useCase.fetchCount == 1)
        #expect(viewModel.state.phase == .finished)
    }

    @Test func `valid cache with sections skips the network`() async {
        useCase.cacheValid = true
        useCase.cachedSections = .success(Self.sections)

        let viewModel = await launch()

        #expect(useCase.fetchCount == 0)
        #expect(viewModel.state.phase == .finished)
    }

    @Test(arguments: [false, true])
    func `empty or unreadable cache falls back to the network`(unreadable: Bool) async {
        useCase.cacheValid = true
        useCase.cachedSections = unreadable ? .failure(StubError()) : .success([])
        useCase.fetchResults = [.success(Self.sections)]

        _ = await launch()

        #expect(useCase.fetchCount == 1)
        #expect(useCase.cachedSectionWrites.count == 1)
    }

    @Test func `failed cache write does not stop the launch`() async {
        useCase.fetchResults = [.success(Self.sections)]
        useCase.failsToCache = true

        let viewModel = await launch()

        #expect(viewModel.state == SplashViewModel.State(phase: .finished, retry: nil))
        #expect(finishes.count == 1)
    }

    @Test func `failed fetch recovers on a retry`() async {
        useCase.fetchResults = [.failure(StubError()), .success(Self.sections)]

        let viewModel = await launch()

        #expect(useCase.fetchCount == 2)
        #expect(useCase.cachedSectionWrites.count == 1)
        #expect(viewModel.state.phase == .finished)
    }

    // A splash the user cannot leave is worse than an empty Home with its own retry.
    @Test(arguments: [Result<[HomeSection], StubError>.failure(StubError()), .success([])])
    func `three failed retries still enter the app`(result: Result<[HomeSection], StubError>) async {
        useCase.fetchResults = [result]

        let viewModel = await launch()

        #expect(useCase.fetchCount == 4)
        #expect(viewModel.state.phase == .finished)
        #expect(finishes.count == 1)
    }

    // The app's root reacts to the finish by redrawing, and the redraw reads the state:
    // called from inside `update`, that read is an exclusivity violation and a crash.
    @Test func `the finish callback can read the state it finished with`() async {
        useCase.fetchResults = [.success(Self.sections)]
        var phaseSeenOnFinish: SplashViewModel.State.Phase?
        var viewModel: SplashViewModel?
        viewModel = SplashViewModel(getSplash: useCase, players: player, analytics: analytics, retryDelay: .zero) {
            phaseSeenOnFinish = viewModel?.state.phase
        }

        await viewModel?.settled()

        #expect(phaseSeenOnFinish == .finished)
    }

    @Test func `the splash is tracked as a screen when it starts`() async {
        _ = await launch()

        #expect(backend.logged(.screenView(.splash)))
    }

    @Test func `continue outside the explainer changes nothing`() async {
        let viewModel = await launch()
        var state = SplashViewModel.State(phase: .loading, retry: nil)

        viewModel.update(state: &state, message: .viewAction(.continuePastExplainer))

        #expect(state == SplashViewModel.State(phase: .loading, retry: nil))
        #expect(!backend.logged(.permissionContinueTap))
    }

    @Test(arguments: [SplashViewModel.Message.fetchFailed, .fetched([])])
    func `each failure counts one attempt until the third one finishes`(failure: SplashViewModel.Message) async {
        let viewModel = await launch()
        let finished = finishes.count
        var state = SplashViewModel.State(phase: .loading, retry: nil)
        let reason: SplashViewModel.State.RetryReason = if case .fetchFailed = failure { .connectionError } else { .noData }

        for attempt in 1...3 {
            viewModel.update(state: &state, message: failure)
            #expect(state.retry == SplashViewModel.State.Retry(attempt: attempt, of: 3, reason: reason))
        }
        viewModel.update(state: &state, message: failure)
        await viewModel.settled()

        #expect(state == SplashViewModel.State(phase: .finished, retry: nil))
        #expect(finishes.count == finished + 1)
    }

    @Test func `messages after finishing are ignored`() async {
        let viewModel = await launch()
        var state = viewModel.state

        viewModel.update(state: &state, message: .cached)
        viewModel.update(state: &state, message: .viewAction(.continuePastExplainer))

        #expect(state == SplashViewModel.State(phase: .finished, retry: nil))
        #expect(finishes.count == 1)
    }

    @Test func `the node is named after the phase and always lists Continue`() async throws {
        useCase.authorizationDetermined = false
        let viewModel = await launch()
        let session = IntrospectionSession(root: viewModel)

        #expect(session.handle("ls").hasPrefix("MusicExplainer\n"))
        #expect(session.handle("ls").hasSuffix("actions Continue"))
        useCase.fetchResults = [.success(Self.sections)]
        #expect(session.handle("do Continue") == "ok")
        await viewModel.settled()

        #expect(session.handle("ls").hasPrefix("Splash\n"))
        #expect(session.handle("ls").contains(#""phase":"finished""#))
        #expect(session.handle("ls").hasSuffix("actions Continue"))
    }
}
