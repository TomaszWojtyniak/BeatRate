import Analytics
import Foundation
import HomeUseCases
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

/// Main-actor classes because the use-case protocols inherit their package's
/// default main-actor isolation.
@MainActor
final class StubHomeUseCases: GetHomeUseCaseProtocol, SetHomeUseCaseProtocol {
    /// Each fetch takes the next result; the last one repeats.
    var results: [Result<[HomeSection], StubError>] = [.success([])]
    var failsToClear = false
    private(set) var fetchCount = 0
    private(set) var clearCount = 0

    func fetchHomeSections() async throws -> [HomeSection] {
        let result = results[min(fetchCount, results.count - 1)]
        fetchCount += 1
        return try result.get()
    }

    func clearCache() async throws {
        clearCount += 1
        if failsToClear { throw StubError() }
    }
}
