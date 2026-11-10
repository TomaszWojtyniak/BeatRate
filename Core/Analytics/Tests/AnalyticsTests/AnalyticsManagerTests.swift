import Foundation
import Testing
@testable import Analytics

@MainActor
struct AnalyticsManagerTests {
    private let backend = StubAnalyticsBackend()
    private let defaults = UserDefaults(suiteName: UUID().uuidString)!

    private func makeManager(enabled: Bool = false) -> AnalyticsManager {
        let manager = AnalyticsManager(defaults: defaults, backend: backend)
        if enabled { manager.setAnalyticsEnabled(true) }
        return manager
    }

    @Test func `consent is nil until the user has been asked`() {
        #expect(makeManager().consent == nil)
    }

    @Test(arguments: [true, false])
    func `set consent stores the answer and applies it`(granted: Bool) {
        let manager = makeManager()

        manager.setConsent(granted)

        #expect(manager.consent == granted)
        #expect(backend.consents == [granted])
        #expect(backend.collectionEnabled == [granted])
    }

    @Test func `revoking consent wipes collected analytics data`() {
        makeManager().setConsent(false)

        #expect(backend.resetCount == 1)
    }

    @Test func `granting consent keeps collected analytics data`() {
        makeManager().setConsent(true)

        #expect(backend.resetCount == 0)
    }

    @Test func `nothing is sent before analytics is enabled`() {
        let manager = makeManager()

        manager.log(.logout)
        manager.setUserId("u1")
        manager.setUserProperty("spotify", forName: "player")

        #expect(backend.events.isEmpty)
        #expect(backend.userIDs.isEmpty)
        #expect(backend.userProperties.isEmpty)
    }

    @Test func `logged event carries its name and parameters`() throws {
        makeManager(enabled: true).log(.tabSelected(tab: "search"))

        let event = try #require(backend.events.first)
        #expect(event.name == "tab_selected")
        #expect(event.parameters?["tab"] as? String == "search")
    }

    @Test func `event without parameters is sent with nil parameters`() throws {
        makeManager(enabled: true).log(.logout)

        let event = try #require(backend.events.first)
        #expect(event.parameters == nil)
    }

    @Test func `user id is forwarded and can be cleared once enabled`() {
        let manager = makeManager(enabled: true)

        manager.setUserId("u1")
        manager.setUserId(nil)

        #expect(backend.userIDs == ["u1", nil])
    }

    @Test func `user property is forwarded once enabled`() throws {
        makeManager(enabled: true).setUserProperty(nil, forName: "player")

        let property = try #require(backend.userProperties.first)
        #expect(property.name == "player")
        #expect(property.value == nil)
    }
}
