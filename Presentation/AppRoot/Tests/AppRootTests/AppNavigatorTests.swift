import Analytics
import Composition
import CoreApp
import IntrospectionKit
import Models
import Testing
@testable import AppRoot

struct AppNavigatorTests {
    @Test func `a guest who finishes the splash lands on the tabs and is asked for consent`() async {
        let harness = Harness()
        let navigator = harness.navigator()
        #expect(navigator.state.phase == .splash)

        harness.finishSplash()
        await eventually { navigator.state.phase == .tabs }

        #expect(navigator.state.phase == .tabs)
        #expect(navigator.state.isAskingAnalyticsConsent)
        #expect(navigator.state.analyticsConsent == nil)
    }

    @Test func `a returning user who answered before is not asked again`() async {
        let navigator = Harness(consent: false).navigator()

        #expect(!navigator.state.isAskingAnalyticsConsent)
        #expect(navigator.state.analyticsConsent == false)
    }

    @Test func `a signed-in user without a player goes to the picker and on to the tabs once one is set`() async {
        let harness = Harness()
        harness.app.isLoggedIn = true
        let navigator = harness.navigator()
        await eventually { navigator.state.isLoggedIn }

        harness.finishSplash()
        await eventually { navigator.state.phase == .playerPicker }
        #expect(navigator.state.phase == .playerPicker)

        harness.players.set(.appleMusic, for: "u1")
        await eventually { navigator.state.phase == .tabs }
        #expect(navigator.state.phase == .tabs)
    }

    @Test func `a login after the splash starts a fresh splash`() async {
        let harness = Harness()
        let navigator = harness.navigator()
        harness.finishSplash()
        await eventually { navigator.state.phase == .tabs }

        harness.app.push(true)
        await eventually { navigator.state.phase == .splash }

        #expect(navigator.state.phase == .splash)
        #expect(harness.splashes.count == 2)
        #expect(navigator.splash === harness.splashes.last)
        #expect(harness.session.isLoggedIn)
    }

    @Test(arguments: [true, false])
    func `the launch login state is mirrored into the session`(isLoggedIn: Bool) async {
        let harness = Harness()
        harness.app.isLoggedIn = isLoggedIn
        harness.session.update(isLoggedIn: !isLoggedIn)
        let navigator = harness.navigator()

        await eventually { harness.session.isLoggedIn == isLoggedIn }

        #expect(navigator.state.isLoggedIn == isLoggedIn)
        #expect(harness.session.isLoggedIn == isLoggedIn)
    }

    @Test func `staying signed in does not replay the splash`() async {
        let harness = Harness()
        let navigator = harness.navigator()
        harness.finishSplash()
        await eventually { navigator.state.phase == .tabs }
        harness.app.push(true)
        await eventually { navigator.state.phase == .splash }
        harness.finishSplash()

        harness.app.push(true)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(harness.splashes.count == 2)
    }

    // Restoring a lost login row inside the splash reports a login; a second splash
    // would check, authorize and fetch all over again.
    @Test func `a login while the splash runs does not start another splash`() async {
        let harness = Harness()
        let navigator = harness.navigator()

        harness.app.push(true)
        await eventually { navigator.state.isLoggedIn }

        #expect(navigator.state.isLoggedIn)
        #expect(harness.splashes.count == 1)
    }

    @Test func `logging out clears the analytics and crash user`() async {
        let harness = Harness(consent: true)
        harness.app.isLoggedIn = true
        harness.app.user = User(isLoggedIn: true, userId: "u1")
        let navigator = harness.navigator()
        await eventually { navigator.state.userId == "u1" }
        #expect(harness.crash.userIDs == ["u1"])

        harness.app.push(false)
        await eventually { !navigator.state.isLoggedIn }

        #expect(!harness.session.isLoggedIn)
        #expect(harness.backend.userIDs == ["u1", nil])
        #expect(harness.crash.userIDs == ["u1", nil])
    }

    @Test(arguments: [(false, "u1"), (true, "")])
    func `a guest row is not an identity`(isLoggedIn: Bool, userId: String) async {
        let harness = Harness(consent: true)
        harness.app.user = User(isLoggedIn: isLoggedIn, userId: userId)
        let navigator = harness.navigator()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(navigator.state.userId == nil)
        #expect(harness.crash.userIDs.isEmpty)
    }

    @Test(arguments: [true, false])
    func `answering the consent alert stores it and stops asking`(granted: Bool) async {
        let harness = Harness()
        let navigator = harness.navigator()

        navigator.send(action: granted ? .allowAnalytics : .denyAnalytics)
        navigator.send(action: granted ? .denyAnalytics : .allowAnalytics)

        #expect(!navigator.state.isAskingAnalyticsConsent)
        #expect(navigator.state.analyticsConsent == granted)
        #expect(harness.analytics.consent == granted)
    }

    @Test func `granting consent identifies a signed-in user`() async {
        let harness = Harness()
        harness.app.isLoggedIn = true
        harness.app.user = User(isLoggedIn: true, userId: "u1")
        let navigator = harness.navigator()
        await eventually { navigator.state.userId == "u1" }
        #expect(harness.backend.userIDs.isEmpty)

        navigator.send(action: .allowAnalytics)

        #expect(harness.backend.userIDs == ["u1"])
    }

    @Test func `the login prompt follows the session and dismiss closes it`() async {
        let harness = Harness()
        let navigator = harness.navigator()

        harness.session.requestLogin(reason: .rating)
        await eventually { navigator.state.loginPrompt == .rating }
        #expect(navigator.state.loginPrompt == .rating)

        navigator.send(action: .dismissLoginPrompt)

        #expect(navigator.state.loginPrompt == nil)
        #expect(!harness.session.isPresentingLoginPrompt)
    }

    @Test func `a selected tab is tracked`() {
        let harness = Harness(consent: true)
        let navigator = harness.navigator()

        navigator.send(action: .selectedTab("search"))

        #expect(harness.backend.events.contains(AnalyticsEvent.tabSelected(tab: "search").name))
    }

    @Test func `the node shows the prompt over consent and consent over the tabs`() async {
        let harness = Harness()
        harness.app.isLoggedIn = true
        let navigator = harness.navigator()
        let session = IntrospectionSession(root: navigator)
        await eventually { navigator.state.isLoggedIn }
        #expect(session.handle("ls").hasPrefix("Splash\n"))

        harness.finishSplash()
        await eventually { navigator.state.phase == .playerPicker }
        #expect(session.handle("ls").hasPrefix("PlayerPicker\n"))
        #expect(session.handle("ls").contains(#""isLoggedIn":true"#))

        harness.players.set(.appleMusic, for: "u1")
        await eventually { navigator.state.phase == .tabs }
        #expect(session.handle("ls").hasPrefix("AnalyticsConsent\n"))
        #expect(session.handle("ls").hasSuffix("actions AllowAnalytics, DenyAnalytics"))

        harness.session.update(isLoggedIn: false)
        harness.session.requestLogin(reason: .account)
        await eventually { navigator.state.loginPrompt != nil }
        #expect(session.handle("ls").hasPrefix("LoginPrompt\n"))
        #expect(session.handle("ls").contains(#""reason":"account""#))
        #expect(session.handle("do dismiss") == "ok")

        #expect(session.handle("do DenyAnalytics") == "ok")
        #expect(session.handle("ls").hasPrefix("Tabs\n"))
        #expect(session.handle("ls").contains(#""analyticsConsent":false"#))
    }

    @Test func `allow analytics from the node stores consent`() async {
        let harness = Harness()
        let navigator = harness.navigator()
        harness.finishSplash()
        await eventually { navigator.state.phase == .tabs }

        #expect(IntrospectionSession(root: navigator).handle("do AllowAnalytics") == "ok")

        #expect(navigator.state.analyticsConsent == true)
    }

    @Test func `the root builds one graph, hands it to legacy screens and shows the navigator`() {
        let app = BeatRateApp(edges: .stub())

        #expect(Graph.current === app.graph)
        #expect(app.introspectionNode.name == "App")
        #expect(app.introspectionNode.state as? AppNavigator.State == app.navigator.state)
        #expect(app.navigator.state.phase == .splash)
    }
}
