import Foundation
import Synchronization
@testable import Analytics

/// Records every Firebase Analytics call instead of sending it.
@MainActor
final class StubAnalyticsBackend: AnalyticsBackend {
    private(set) var consents: [Bool] = []
    private(set) var collectionEnabled: [Bool] = []
    private(set) var resetCount = 0
    private(set) var userProperties: [(name: String, value: String?)] = []
    private(set) var events: [(name: String, parameters: [String: Any]?)] = []
    private(set) var userIDs: [String?] = []

    func setConsent(analyticsGranted: Bool) { consents.append(analyticsGranted) }
    func setCollectionEnabled(_ enabled: Bool) { collectionEnabled.append(enabled) }
    func resetData() { resetCount += 1 }
    func setUserProperty(_ value: String?, forName name: String) { userProperties.append((name, value)) }
    func logEvent(_ name: String, parameters: [String: Any]?) { events.append((name, parameters)) }
    func setUserID(_ userId: String?) { userIDs.append(userId) }
}

/// Records every Crashlytics call instead of sending it.
final class StubCrashBackend: CrashBackend {
    struct Calls {
        var collectionEnabled: [Bool] = []
        var userIDs: [String?] = []
        var errors: [NSError] = []
        var breadcrumbs: [String] = []
        var customValues: [String: String] = [:]
    }

    private let state = Mutex(Calls())

    var calls: Calls { state.withLock { $0 } }

    func setCollectionEnabled(_ enabled: Bool) { state.withLock { $0.collectionEnabled.append(enabled) } }
    func setUserID(_ userId: String?) { state.withLock { $0.userIDs.append(userId) } }
    func record(_ error: Error) { state.withLock { $0.errors.append(error as NSError) } }
    func log(_ message: String) { state.withLock { $0.breadcrumbs.append(message) } }
    func setCustomValue(_ value: String, forKey key: String) { state.withLock { $0.customValues[key] = value } }
}
