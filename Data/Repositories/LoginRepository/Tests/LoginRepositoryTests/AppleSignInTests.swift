import Foundation
import Testing
@testable import LoginRepository

@MainActor
struct AppleSignInTests {
    private let log = CallLog()
    private let auth: StubAuthFirebaseService
    private let database: StubDatabaseFirebaseService
    private let repository: LoginRepository

    init() {
        auth = StubAuthFirebaseService(log: log)
        database = StubDatabaseFirebaseService(log: log)
        repository = LoginRepository(authFirebaseService: auth, databaseFirebaseService: database)
    }

    // MARK: - Sign in

    @Test func `sign in sends apple's token with the nonce in flight`() async throws {
        let nonce = await repository.getCurrentNonce()

        let userId = try await repository.setLoginData(credential: Fixture.credential())

        #expect(userId == "firebase-uid")
        #expect(auth.signIns.map(\.idToken) == ["token"])
        #expect(auth.signIns.map(\.nonce) == [nonce])
        #expect(auth.signIns.map(\.appleUser) == ["apple-user"])
    }

    // A callback with no nonce was not started by this app.
    @Test func `sign in without a nonce in flight is rejected`() async {
        await #expect(throws: LoginError.wrongData) { try await repository.setLoginData(credential: Fixture.credential()) }
        #expect(auth.signIns.isEmpty)
    }

    @Test(arguments: [nil, Data([0xFF, 0xFE])] as [Data?])
    func `sign in without a readable identity token is rejected`(token: Data?) async {
        _ = await repository.getCurrentNonce()

        await #expect(throws: LoginError.wrongData) { try await repository.setLoginData(credential: Fixture.credential(token: token)) }
        #expect(auth.signIns.isEmpty)
    }

    // MARK: - Account deletion

    // Re-auth and the data wipe need a live session; the auth user goes last.
    @Test func `account is deleted in order while still signed in`() async throws {
        let nonce = await repository.getCurrentNonce()

        try await repository.deleteAccount(userId: "u", credential: Fixture.credential())

        #expect(log.calls == ["reauthenticate", "deleteUserData:u", "revokeAndDelete"])
        #expect(auth.reauthentications.first?.nonce == nonce)
        #expect(auth.reauthentications.first?.givenName == "Ann")
        #expect(auth.revokedCodes == ["code"])
    }

    @Test(arguments: [nil, Data([0xFF, 0xFE])] as [Data?])
    func `missing authorization code still deletes the account`(code: Data?) async throws {
        _ = await repository.getCurrentNonce()

        try await repository.deleteAccount(userId: "u", credential: Fixture.credential(code: code))

        #expect(auth.revokedCodes == [nil])
    }

    @Test func `failed data wipe keeps the firebase user`() async {
        _ = await repository.getCurrentNonce()
        database.failsToDeleteData = true

        await #expect(throws: StubError.self) { try await repository.deleteAccount(userId: "u", credential: Fixture.credential()) }
        #expect(log.calls == ["reauthenticate", "deleteUserData:u"])
    }

    @Test func `deletion without a nonce or token touches nothing`() async {
        await #expect(throws: LoginError.wrongData) { try await repository.deleteAccount(userId: "u", credential: Fixture.credential()) }
        _ = await repository.getCurrentNonce()
        await #expect(throws: LoginError.wrongData) { try await repository.deleteAccount(userId: "u", credential: Fixture.credential(token: nil)) }

        #expect(log.calls.isEmpty)
    }
}
