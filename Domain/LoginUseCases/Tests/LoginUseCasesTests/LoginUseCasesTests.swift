import FirebaseService
import Models
import Testing
@testable import LoginUseCases

@MainActor
struct LoginUseCasesTests {
    private let login = StubLoginRepository()
    private let cache = StubSwiftDataManager()

    private var useCase: SetLoginUseCase { SetLoginUseCase(loginRepository: login, swiftDataManager: cache) }

    @Test func `successful sign in is stored locally`() async throws {
        let userId = try await useCase.performCompleteLogin(credential: .fixture)

        #expect(userId == "u")
        #expect(cache.loggedInUserIds == ["u"])
        #expect(login.signOutCount == 0)
    }

    @Test func `failed firebase sign in stores nothing`() async {
        login.loginResult = .failure(StubError())

        await #expect(throws: LoginUseCaseError.authenticationFailed) {
            try await useCase.performCompleteLogin(credential: .fixture)
        }
        #expect(cache.loggedInUserIds.isEmpty)
    }

    // Half a login — signed in to Firebase, guest locally — is worse than none.
    @Test(arguments: [false, true])
    func `local storage failure rolls back the firebase sign in`(rollbackFails: Bool) async {
        cache.failsToLogIn = true
        login.failsToSignOut = rollbackFails

        await #expect(throws: LoginUseCaseError.localStorageFailed) {
            try await useCase.performCompleteLogin(credential: .fixture)
        }
        #expect(login.signOutCount == 1)
    }

    @Test(arguments: [LoginUseCaseError.localStorageFailed, .authenticationFailed])
    func `every login error explains itself`(error: LoginUseCaseError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func `profile is saved and read through the login repository`() async throws {
        let profile = FirebaseUserProfile(email: "a@b.c", firstName: "Ann", lastName: nil)
        login.profiles = ["u": profile]

        try await useCase.saveUserProfile(userId: "u", profile: profile)
        let loaded = try await GetLoginUseCase(loginRepository: login).getUserProfile(userId: "u")

        #expect(login.savedProfiles.map(\.userId) == ["u"])
        #expect(loaded?.email == "a@b.c")
    }

    @Test func `nonce comes from the login repository`() async {
        login.nonce = "abc"

        #expect(await GetLoginUseCase(loginRepository: login).getCurrentNonce() == "abc")
    }
}
