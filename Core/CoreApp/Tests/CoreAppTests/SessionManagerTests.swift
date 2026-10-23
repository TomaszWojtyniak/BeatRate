import Testing
@testable import CoreApp

@MainActor
struct SessionManagerTests {
    private let session = SessionManager()

    @Test func `fresh install starts as a guest with no prompt`() {
        #expect(!session.isLoggedIn)
        #expect(!session.isPresentingLoginPrompt)
        #expect(session.loginPromptReason == .account)
    }

    @Test func `signing in dismisses an open login prompt`() {
        session.requestLogin(reason: .rating)

        session.update(isLoggedIn: true)

        #expect(session.isLoggedIn)
        #expect(!session.isPresentingLoginPrompt)
    }

    @Test func `repeating the same login state changes nothing`() {
        session.requestLogin(reason: .rating)

        session.update(isLoggedIn: false)

        #expect(session.isPresentingLoginPrompt)
    }

    @Test func `signing out keeps the user a guest without raising the prompt`() {
        session.update(isLoggedIn: true)

        session.update(isLoggedIn: false)

        #expect(!session.isLoggedIn)
        #expect(!session.isPresentingLoginPrompt)
    }

    @Test(arguments: [LoginPromptReason.account, .rating])
    func `guest login request raises the prompt with its reason`(reason: LoginPromptReason) {
        session.requestLogin(reason: reason)

        #expect(session.isPresentingLoginPrompt)
        #expect(session.loginPromptReason == reason)
    }

    @Test func `login request is ignored when already signed in`() {
        session.update(isLoggedIn: true)

        session.requestLogin(reason: .rating)

        #expect(!session.isPresentingLoginPrompt)
    }

    @Test func `account tab auto prompts a guest only once`() {
        session.autoPromptForAccountIfNeeded()
        session.isPresentingLoginPrompt = false

        session.autoPromptForAccountIfNeeded()

        #expect(!session.isPresentingLoginPrompt)
    }

    @Test func `first account tab visit raises the account prompt`() {
        session.autoPromptForAccountIfNeeded()

        #expect(session.isPresentingLoginPrompt)
        #expect(session.loginPromptReason == .account)
    }

    @Test func `account tab does not prompt right after a deliberate logout`() {
        session.userDidLogout()

        session.autoPromptForAccountIfNeeded()

        #expect(!session.isPresentingLoginPrompt)
    }

    @Test func `account tab does not prompt a signed in user`() {
        session.update(isLoggedIn: true)

        session.autoPromptForAccountIfNeeded()

        #expect(!session.isPresentingLoginPrompt)
    }
}
