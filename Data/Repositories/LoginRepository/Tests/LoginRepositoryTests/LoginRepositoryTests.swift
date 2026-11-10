import Models
import Testing
@testable import LoginRepository

@MainActor
struct LoginRepositoryTests {
    private let auth = StubAuthFirebaseService()
    private let database = StubDatabaseFirebaseService()

    private var repository: LoginRepository {
        LoginRepository(authFirebaseService: auth, databaseFirebaseService: database)
    }

    // Apple's callback is checked against this nonce, so it must not change mid-flow.
    @Test func `nonce stays the same for the whole sign in attempt`() async {
        let repository = repository

        let first = await repository.getCurrentNonce()
        let second = await repository.getCurrentNonce()

        #expect(first == second)
    }

    @Test func `nonce is 32 url safe characters`() async {
        let nonce = await repository.getCurrentNonce()
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        #expect(nonce.count == 32)
        #expect(nonce.allSatisfy(allowed.contains))
    }

    @Test func `separate repositories get different nonces`() async {
        #expect(await repository.getCurrentNonce() != (await repository.getCurrentNonce()))
    }

    @Test(arguments: ["uid", nil] as [String?])
    func `firebase user id comes from the auth session`(userId: String?) async {
        auth.userId = userId

        #expect(await repository.currentFirebaseUserId() == userId)
    }

    @Test func `profile is read and saved through the database`() async throws {
        let profile = FirebaseUserProfile(email: "a@b.c", firstName: "Ann", lastName: "Lee")
        database.profiles = ["u": profile]
        let repository = repository

        let loaded = try await repository.getUserProfile(userId: "u")
        try await repository.saveUserProfile(userId: "u", profile: profile)

        #expect(loaded?.email == "a@b.c")
        #expect(database.savedProfiles["u"]?.firstName == "Ann")
        #expect(try await repository.getUserProfile(userId: "missing") == nil)
    }

    @Test func `sign out goes to firebase`() async throws {
        try await repository.signOut()

        #expect(auth.signOutCount == 1)
    }

    @Test func `failed sign out is passed on`() async {
        auth.signOutError = StubError()

        await #expect(throws: StubError.self) { try await repository.signOut() }
    }
}
