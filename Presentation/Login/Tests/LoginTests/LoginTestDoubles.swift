import Analytics
import AuthenticationServices
import Foundation
import LoginUseCases
import Models

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

/// One stub for both login use cases. Main-actor because the protocols inherit
/// their package's default main-actor isolation.
@MainActor
final class StubLoginUseCases: GetLoginUseCaseProtocol, SetLoginUseCaseProtocol {
    var failsToLogIn = false
    private(set) var loggedInUsers: [String] = []

    func getCurrentNonce() async -> String { "nonce" }
    func getUserProfile(userId: String) async throws -> FirebaseUserProfile? { nil }
    func performCompleteLogin(credential: AppleSignInCredential) async throws -> String {
        if failsToLogIn { throw LoginUseCaseError.authenticationFailed }
        loggedInUsers.append(credential.user)
        return "u"
    }
    func saveUserProfile(userId: String, profile: FirebaseUserProfile) async throws {}
}
