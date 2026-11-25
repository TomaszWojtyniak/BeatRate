import Analytics
import CoreApp
import Foundation
import Testing
@testable import FirebaseService

@MainActor
struct AuthSessionTests {
    static let credential = AppleSignInCredential(user: "apple-1", identityToken: Data("token".utf8), authorizationCode: nil, email: nil, fullName: nil)

    static func service(auth: StubFirebaseAuth, keychain: StubKeychainBackend = StubKeychainBackend(failing: false)) -> AuthFirebaseService {
        AuthFirebaseService(auth: auth, analyticsManager: makeAnalytics(), databaseService: StubDatabaseFirebaseService(),
                            keychainManager: KeychainManager(backend: keychain))
    }

    static func serviceWithAnalytics(auth: StubFirebaseAuth) -> (AuthFirebaseService, StubAnalyticsBackend) {
        let backend = StubAnalyticsBackend()
        let analytics = makeAnalytics(backend)
        analytics.setAnalyticsEnabled(true)
        let service = AuthFirebaseService(auth: auth, analyticsManager: analytics, databaseService: StubDatabaseFirebaseService(),
                                          keychainManager: KeychainManager(backend: StubKeychainBackend(failing: false)))
        return (service, backend)
    }

    @Test func `the signed-in user is the one in Firebase's own session`() async {
        let service = Self.service(auth: StubFirebaseAuth(currentUser: "u1"))

        #expect(await service.currentUserId() == "u1")
    }

    @Test func `a keychain failure signs the new Firebase session back out`() async {
        let auth = StubFirebaseAuth(signInResult: .init(userId: "u1", email: nil, isNewUser: true))
        let service = Self.service(auth: auth, keychain: StubKeychainBackend(failing: true))

        await #expect(throws: (any Error).self) {
            _ = try await service.setLoginData(idTokenString: "token", nonce: "nonce", credential: Self.credential)
        }
        #expect(await auth.signOutCount == 1)
    }

    // The caller must learn why sign-in failed, not that the cleanup failed too.
    @Test func `a failed rollback still surfaces the keychain error`() async {
        let auth = StubFirebaseAuth(signOutError: StubError())
        let service = Self.service(auth: auth, keychain: StubKeychainBackend(failing: true))

        await #expect(throws: KeychainError.saveFailed) {
            _ = try await service.setLoginData(idTokenString: "token", nonce: "nonce", credential: Self.credential)
        }
    }

    @Test(arguments: [(true, "sign_up"), (false, "login")])
    func `only the first sign-in is reported as a sign up`(isNewUser: Bool, event: String) async throws {
        let auth = StubFirebaseAuth(signInResult: .init(userId: "u1", email: nil, isNewUser: isNewUser))
        let (service, analytics) = Self.serviceWithAnalytics(auth: auth)

        _ = try await service.setLoginData(idTokenString: "token", nonce: "nonce", credential: Self.credential)

        #expect(analytics.events.map(\.name).contains(event))
    }

    // Leaving the Apple user ID behind is harmless; staying signed in is not.
    @Test(arguments: [false, true])
    func `sign out ends the Firebase session whatever the keychain cleanup does`(keychainFails: Bool) async throws {
        let auth = StubFirebaseAuth()

        try await Self.service(auth: auth, keychain: StubKeychainBackend(failing: keychainFails)).signOut()

        #expect(await auth.signOutCount == 1)
    }

    @Test func `reauthentication hands Firebase the fresh Apple token`() async throws {
        let auth = StubFirebaseAuth()

        try await Self.service(auth: auth).reauthenticate(idTokenString: "fresh", nonce: "nonce", fullName: nil)

        #expect(await auth.reauthenticatedTokens == ["fresh"])
    }

    @Test func `deleting with nobody signed in throws noCurrentUser`() async {
        let service = Self.service(auth: StubFirebaseAuth(currentUser: nil))

        await #expect(throws: AuthFirebaseServiceError.noCurrentUser) {
            try await service.revokeAndDeleteUser(authorizationCode: "code")
        }
    }

    @Test func `deleting revokes the Apple token and then the account`() async throws {
        let auth = StubFirebaseAuth()

        try await Self.service(auth: auth).revokeAndDeleteUser(authorizationCode: "code")

        #expect(await auth.revokedCodes == ["code"])
        #expect(await auth.deleteCount == 1)
    }

    @Test func `a failed token revoke still deletes the account`() async throws {
        let auth = StubFirebaseAuth(currentUser: "u1", revokeError: StubError())

        try await Self.service(auth: auth).revokeAndDeleteUser(authorizationCode: "code")

        #expect(await auth.deleteCount == 1)
    }
}
