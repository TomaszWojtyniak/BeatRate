import CoreApp
import Foundation
import Testing
@testable import BeatRateFixtures

struct FakeEdgesTests {
    @Test func `the keychain keeps, replaces and forgets an item by account`() async throws {
        let keychain = KeychainManager(backend: FakeKeychainBackend())

        try await keychain.saveAppleUserID("apple-1")
        try await keychain.saveAppleUserID("apple-2")
        #expect(try await keychain.loadAppleUserID() == "apple-2")

        try await keychain.deleteAppleUserID()
        try await keychain.deleteAppleUserID()
        #expect(try await keychain.loadAppleUserID() == nil)
    }

    @Test func `signing out ends the session the fixture started`() async throws {
        let auth = FakeFirebaseAuth(userId: "u1")

        try await auth.signOut()

        #expect(await auth.currentUserId() == nil)
    }

    @Test func `sign-in flows refuse until fixtures script them`() async {
        let auth = FakeFirebaseAuth(userId: "u1")

        await #expect(throws: FakeAuthError.notScripted) { _ = try await auth.signIn(idToken: "t", rawNonce: "n", fullName: nil) }
        await #expect(throws: FakeAuthError.notScripted) { try await auth.reauthenticate(idToken: "t", rawNonce: "n", fullName: nil) }
        await #expect(throws: FakeAuthError.notScripted) { try await auth.revokeToken(authorizationCode: "c") }
        await #expect(throws: FakeAuthError.notScripted) { try await auth.deleteCurrentUser() }
    }

    @Test func `analytics keeps the names of logged events and ignores the rest`() {
        let analytics = FakeAnalyticsBackend()

        analytics.setConsent(analyticsGranted: true)
        analytics.setCollectionEnabled(true)
        analytics.setUserProperty("x", forName: "p")
        analytics.setUserID("u1")
        analytics.logEvent("screen_view", parameters: nil)
        analytics.resetData()

        #expect(analytics.events == ["screen_view"])
    }
}
