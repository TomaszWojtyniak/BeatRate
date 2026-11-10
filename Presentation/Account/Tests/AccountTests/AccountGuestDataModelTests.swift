import Analytics
import CoreApp
import Testing
@testable import Account

@MainActor
struct AccountGuestDataModelTests {
    private let session = SessionManager()
    private let backend: StubAnalyticsBackend
    private let model: AccountGuestDataModel

    init() {
        let analytics: AnalyticsManager
        (analytics, backend) = makeAnalytics()
        model = AccountGuestDataModel(sessionManager: session, analyticsManager: analytics)
    }

    @Test func `first visit raises the sign in prompt once`() {
        model.autoPromptIfNeeded()
        session.isPresentingLoginPrompt = false
        model.autoPromptIfNeeded()

        #expect(!session.isPresentingLoginPrompt)
        #expect(!model.isLoggedIn)
    }

    @Test func `sign in button raises the prompt and is tracked`() {
        model.requestLogin()
        model.track(.screenView(.accountGuest))

        #expect(session.isPresentingLoginPrompt)
        #expect(session.loginPromptReason == .account)
        #expect(backend.logged(.guestSignInTap))
        #expect(backend.logged(.screenView(.accountGuest)))
    }
}
