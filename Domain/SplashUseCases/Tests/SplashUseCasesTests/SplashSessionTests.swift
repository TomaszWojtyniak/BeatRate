import AuthenticationServices
import LoginRepository
import Testing
@testable import SplashUseCases

@MainActor
struct SplashSessionTests {

    // MARK: - Login state

    @Test func `locally signed in user is signed in`() async {
        let harness = SplashTestHarness()
        harness.signIn()

        #expect(await harness.useCase.isUserLoggedIn())
    }

    @Test func `guest without an apple id stays a guest`() async {
        let harness = SplashTestHarness()
        harness.login.firebaseUserId = "u"

        #expect(await !harness.useCase.isUserLoggedIn())
        #expect(harness.cache.loggedInUserIds.isEmpty)
    }

    @Test func `apple id without a firebase session stays a guest`() async {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(appleUserID: "apple"))

        #expect(await !harness.useCase.isUserLoggedIn())
    }

    // A reset cache store must not silently demote a signed-in user to guest.
    @Test func `login row is rebuilt from the keychain and firebase after a cache reset`() async {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(appleUserID: "apple"))
        harness.login.firebaseUserId = "u"

        #expect(await harness.useCase.isUserLoggedIn())
        #expect(harness.cache.loggedInUserIds == ["u"])
    }

    @Test func `failed rebuild of the login row reads as a guest`() async {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(appleUserID: "apple"))
        harness.login.firebaseUserId = "u"
        harness.cache.failsToLogIn = true

        #expect(await !harness.useCase.isUserLoggedIn())
    }

    // MARK: - Credentials

    @Test func `authorized apple credentials are valid`() async {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(appleUserID: "apple"))

        #expect(await harness.useCase.areCredentialsValid())
        #expect(harness.login.signOutCount == 0)
    }

    @Test(arguments: [.revoked, .notFound, .transferred] as [ASAuthorizationAppleIDProvider.CredentialState])
    func `lost apple credentials log the user out`(state: ASAuthorizationAppleIDProvider.CredentialState) async {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(appleUserID: "apple"), credentialState: state)
        harness.signIn()

        #expect(await !harness.useCase.areCredentialsValid())
        #expect(harness.login.signOutCount == 1)
        #expect(!harness.cache.loggedIn)
    }

    @Test(arguments: [false, true])
    func `missing or unreadable apple id is invalid and logs out`(unreadable: Bool) async {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(failsToLoad: unreadable))

        #expect(await !harness.useCase.areCredentialsValid())
        #expect(harness.login.signOutCount == 1)
    }

    @Test func `failed forced logout still reports invalid credentials`() async {
        let harness = SplashTestHarness()
        harness.login.failsToSignOut = true

        #expect(await !harness.useCase.areCredentialsValid())
    }

    // MARK: - Logout

    @Test func `logout tears down firebase, keychain, caches and the users player`() async throws {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(appleUserID: "apple"))
        harness.signIn()
        harness.player.set(.spotify, for: "u")

        try await harness.useCase.logout()

        #expect(harness.login.signOutCount == 1)
        #expect(harness.keychain.deletedAppleID)
        #expect(harness.keychain.deletedSpotifyTokens)
        #expect(harness.home.invalidateCount == 1)
        #expect(harness.cache.logOutCount == 1)
        #expect(harness.player.current == nil)
        #expect(harness.defaults.mainMusicPlayer(for: "u") == nil)
    }

    // Dropping to guest must not raise the Account sign-in sheet straight away.
    @Test func `logout keeps the account tab from prompting at once`() async throws {
        let harness = SplashTestHarness()

        try await harness.useCase.logout()
        harness.session.autoPromptForAccountIfNeeded()

        #expect(!harness.session.isPresentingLoginPrompt)
    }

    @Test func `failed firebase sign out stops the logout`() async {
        let harness = SplashTestHarness()
        harness.login.failsToSignOut = true

        await #expect(throws: StubError.self) { try await harness.useCase.logout() }
        #expect(harness.cache.logOutCount == 0)
    }

    // MARK: - Account deletion

    @Test func `account is deleted remotely then torn down like a logout`() async throws {
        let harness = SplashTestHarness(keychain: StubAppleCredentialStore(appleUserID: "apple"))
        harness.signIn()

        try await harness.useCase.deleteAccount(credential: .fixture)

        #expect(harness.login.deletedAccounts == ["u"])
        #expect(harness.login.signOutCount == 1)
        #expect(harness.cache.logOutCount == 1)
        #expect(harness.keychain.deletedAppleID)
    }

    // Logging out would report a deletion that never happened.
    @Test func `deletion without a user id fails loudly`() async {
        let harness = SplashTestHarness()

        await #expect(throws: LoginError.wrongData) { try await harness.useCase.deleteAccount(credential: .fixture) }
        #expect(harness.login.deletedAccounts.isEmpty)
        #expect(harness.login.signOutCount == 0)
    }

    @Test func `failed remote deletion keeps the user signed in`() async {
        let harness = SplashTestHarness()
        harness.signIn()
        harness.login.failsToDeleteAccount = true

        await #expect(throws: StubError.self) { try await harness.useCase.deleteAccount(credential: .fixture) }
        #expect(harness.cache.logOutCount == 0)
    }
}
