import Analytics
import AuthenticationServices
import Foundation
import Models
import SplashUseCases
import SpotifyService

struct StubError: Error {}

/// Records every analytics call instead of sending it to Firebase.
@MainActor
final class StubAnalyticsBackend: AnalyticsBackend {
    private(set) var events: [(name: String, parameters: [String: Any]?)] = []

    func logEvent(_ name: String, parameters: [String: Any]?) {
        events.append((name, parameters))
    }

    func setConsent(analyticsGranted: Bool) {}
    func setCollectionEnabled(_ enabled: Bool) {}
    func resetData() {}
    func setUserProperty(_ value: String?, forName name: String) {}
    func setUserID(_ userId: String?) {}

    /// Whether `event` was logged with exactly its name and parameters.
    func logged(_ event: AnalyticsEvent) -> Bool {
        let expected = event.parameters as NSDictionary
        return events.contains { $0.name == event.name && (($0.parameters ?? [:]) as NSDictionary) == expected }
    }
}

/// An opted-in analytics manager over its own defaults suite, recording into a stub.
@MainActor
func makeAnalytics() -> (AnalyticsManager, StubAnalyticsBackend) {
    let backend = StubAnalyticsBackend()
    let manager = AnalyticsManager(defaults: UserDefaults(suiteName: "Analytics.\(UUID())")!, backend: backend)
    manager.setAnalyticsEnabled(true)
    return (manager, backend)
}

/// Main-actor because the protocol inherits its package's default main-actor isolation.
@MainActor
final class StubSplashUseCase: GetSplashUseCaseProtocol {
    var cachedSections: Result<[HomeSection], StubError> = .success([])
    /// Each fetch takes the next result; the last one repeats.
    var fetchResults: [Result<[HomeSection], StubError>] = [.success([])]
    var failsToCache = false
    private(set) var fetchCount = 0
    private(set) var credentialChecks = 0
    var musicKitAuthorized = true
    var authorizationDetermined = true
    var playerHydrated = true
    var spotifyConnection = SpotifyConnectionState.connected(premium: .premium)
    var cacheValid = false
    var loggedIn = false
    var credentialsValid = true
    var failsToLogOut = false
    private(set) var logoutCount = 0
    private(set) var cachedSectionWrites: [[HomeSection]] = []
    private(set) var refreshedPremium: [SpotifyPremiumStatus] = []
    private(set) var musicKitAuthorizationRequests = 0

    func getCachedSections() async throws -> [HomeSection] { try cachedSections.get() }

    func fetchHomeSections() async throws -> [HomeSection] {
        let result = fetchResults[min(fetchCount, fetchResults.count - 1)]
        fetchCount += 1
        return try result.get()
    }

    func authorizeMusicKit() async -> Bool {
        musicKitAuthorizationRequests += 1
        return musicKitAuthorized
    }

    func isMusicKitAuthorizationDetermined() async -> Bool { authorizationDetermined }
    func hydrateMainMusicPlayer() async -> Bool { playerHydrated }
    func verifySpotifyConnection() async -> SpotifyConnectionState { spotifyConnection }
    func refreshSpotifyPremium(_ premium: SpotifyPremiumStatus) async { refreshedPremium.append(premium) }
    func cacheSections(_ sections: [HomeSection]) async throws {
        if failsToCache { throw StubError() }
        cachedSectionWrites.append(sections)
    }
    func isCacheValid() async -> Bool { cacheValid }
    func isUserLoggedIn() async -> Bool { loggedIn }
    func areCredentialsValid() async -> Bool {
        credentialChecks += 1
        return credentialsValid
    }

    func logout() async throws {
        logoutCount += 1
        if failsToLogOut { throw StubError() }
    }

    func getCurrentNonce() async -> String { "nonce" }
    func deleteAccount(credential: AppleSignInCredential) async throws {}
}
