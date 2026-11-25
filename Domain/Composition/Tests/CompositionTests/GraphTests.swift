import Analytics
import Foundation
import Testing
@testable import Composition

@MainActor
struct GraphTests {

    @Test func `a graph built from stub edges starts as a guest`() async {
        let graph = Graph(edges: .stub())

        #expect(await graph.getApp.isUserLoggedIn() == false)
    }

    @Test func `the splash retries two seconds apart unless the edges say otherwise`() {
        var edges = Edges.stub()
        #expect(Graph(edges: edges).retryDelay == .seconds(2))

        edges.retryDelay = .zero
        #expect(Graph(edges: edges).retryDelay == .zero)
    }

    @Test func `analytics consent stored in the given defaults is respected`() {
        let defaults = UserDefaults(suiteName: FileManager.default.temporaryDirectory.appending(path: "Graph.\(UUID())").path)!
        defaults.set(true, forKey: "analyticsConsent")

        #expect(Graph(edges: .stub(defaults: defaults)).analytics.consent == true)
    }

    @Test func `analytics events reach the backend from the edges`() {
        let backend = StubAnalyticsBackend()
        let graph = Graph(edges: .stub(analytics: backend))

        graph.analytics.setAnalyticsEnabled(true)
        graph.analytics.log(.screenView(.home))

        #expect(backend.events.map(\.name) == ["screen_view"])
    }
}
