import Analytics
import AuthenticationServices
import Foundation
import LoginUseCases
import Testing
@testable import Login

@MainActor
struct LoginDataModelTests {
    private let backend: StubAnalyticsBackend
    private let login = StubLoginUseCases()
    private let model: LoginDataModel

    private static let credential = AppleSignInCredential(user: "apple", identityToken: Data("token".utf8), authorizationCode: nil, email: nil, fullName: nil)

    init() {
        let analytics: AnalyticsManager
        (analytics, backend) = makeAnalytics()
        model = LoginDataModel(getLoginUseCase: login, postLoginUseCase: login, analyticsManager: analytics)
    }

    @Test func `apple credential completes the login`() async throws {
        try await model.performCompleteLogin(credential: Self.credential)

        #expect(login.loggedInUsers == ["apple"])
        #expect(!model.isLoading)
    }

    @Test func `failed login is passed on and stops loading`() async {
        login.failsToLogIn = true

        await #expect(throws: LoginUseCaseError.authenticationFailed) { try await model.performCompleteLogin(credential: Self.credential) }
        #expect(!model.isLoading)
    }

    @Test(arguments: [
        (LoginUseCaseError.localStorageFailed, "local_storage_failed"),
        (.authenticationFailed, "authentication_failed"),
    ])
    func `login use case failure shows its own message and is tracked`(error: LoginUseCaseError, errorType: String) async {
        await model.handleLoginFailure(error: error)

        #expect(model.isShowingErrorAlert)
        #expect(!model.errorTitle.isEmpty && !model.errorMessage.isEmpty)
        #expect(backend.logged(.loginFailed(errorType: errorType)))
    }

    @Test(arguments: [ASAuthorizationError.Code.unknown, .notHandled, .failed, .invalidResponse])
    func `apple sign in failure shows a message for its code`(code: ASAuthorizationError.Code) async {
        await model.handleLoginFailure(error: ASAuthorizationError(code))

        #expect(model.isShowingErrorAlert)
        #expect(!model.errorMessage.isEmpty)
        #expect(backend.logged(.loginFailed(errorType: "apple_error")))
    }

    @Test func `different failures explain themselves differently`() async {
        await model.handleLoginFailure(error: LoginUseCaseError.localStorageFailed)
        let storage = model.errorMessage
        await model.handleLoginFailure(error: StubError())

        #expect(model.errorMessage != storage)
        #expect(backend.logged(.loginFailed(errorType: "unknown")))
    }

    // Apple compares this hash with the nonce in the identity token.
    @Test func `nonce is hashed with sha256 as lowercase hex`() {
        #expect(model.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func `nonce and events go through the model`() async {
        #expect(await model.getCurrentNonce() == "nonce")

        model.track(.signInAppleTap)

        #expect(backend.logged(.signInAppleTap))
        #expect(!model.isLoading)
    }

    @Test func `successful sign in shows no alert`() async {
        await model.completeSignIn(credential: Self.credential)

        #expect(login.loggedInUsers == ["apple"])
        #expect(!model.isShowingErrorAlert)
    }

    @Test func `failed sign in shows the alert`() async {
        login.failsToLogIn = true

        await model.completeSignIn(credential: Self.credential)

        #expect(model.isShowingErrorAlert)
        #expect(backend.logged(.loginFailed(errorType: "authentication_failed")))
    }

    // A guest who backs out of the Apple sheet just keeps browsing.
    @Test func `cancelled apple sheet is tracked without an alert`() async {
        await model.handleAuthorizationFailure(ASAuthorizationError(.canceled))

        #expect(!model.isShowingErrorAlert)
        #expect(backend.logged(.loginFailed(errorType: "canceled")))
    }

    @Test func `failed apple sheet shows the alert`() async {
        await model.handleAuthorizationFailure(ASAuthorizationError(.failed))

        #expect(model.isShowingErrorAlert)
        #expect(backend.logged(.loginFailed(errorType: "apple_error")))
    }
}
