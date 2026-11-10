import Analytics
import CoreApp
import Foundation
import Models
import SettingUseCases

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

/// One stub for both settings use cases. Main-actor because the protocols
/// inherit their package's default main-actor isolation.
@MainActor
final class StubSettingsUseCases: GetSettingsUseCaseProtocol, SetSettingsUseCaseProtocol {
    var appleMusicConnect: Result<Bool, StubError> = .success(true)
    var spotifyConnect: Result<Bool, StubError> = .success(true)
    var spotifyAlreadyConnected = false
    var failsToSavePlayer = false
    private(set) var spotifyConnectCount = 0
    private(set) var savedPlayers: [MusicPlayer] = []

    func connectAppleMusic() async throws -> Bool { try appleMusicConnect.get() }

    func connectSpotify() async throws -> Bool {
        spotifyConnectCount += 1
        return try spotifyConnect.get()
    }

    func setMainMusicPlayer(_ player: MusicPlayer) async throws {
        if failsToSavePlayer { throw StubError() }
        savedPlayers.append(player)
    }

    func loadSpotifyStatus() async throws -> Bool { spotifyAlreadyConnected }
    func loadAppleMusicStatus() async throws -> Bool { false }
    func getMainMusicPlayer() async throws -> MusicPlayer? { nil }
}
