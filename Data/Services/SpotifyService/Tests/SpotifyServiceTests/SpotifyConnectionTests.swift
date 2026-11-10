import AuthenticationServices
import Foundation
import Testing
@testable import SpotifyService

struct SpotifyConnectionTests {

    @Test(arguments: [
        ("premium" as String?, SpotifyPremiumStatus.premium, true as Bool?),
        ("free", .free, false),
        ("open", .free, false),
        (nil, .unknown, nil),
    ])
    func `premium is read from the product and unknown is never stored as free`(product: String?, status: SpotifyPremiumStatus, isPremium: Bool?) {
        #expect(SpotifyPremiumStatus(product: product) == status)
        #expect(status.isPremium == isPremium)
    }

    @Test(arguments: [
        (SpotifyConnectionState.needsReauth, true),
        (.connected(premium: .premium), false),
        (.notConnected, false),
        (.unavailable, false),
        (.notAllowlisted, false),
    ])
    func `only a dead session asks the user to reconnect`(state: SpotifyConnectionState, requiresAction: Bool) {
        #expect(state.requiresUserAction == requiresAction)
    }

    @Test func `every failure has its own message`() {
        let failures: [SpotifyFailure] = [.noSession, .sessionExpired, .notAllowlisted, .rateLimited(retryAfter: 3), .transient, .authCancelled, .authorizationFailed]

        let messages = failures.compactMap(\.errorDescription)

        #expect(Set(messages).count == failures.count)
    }

    @Test func `auth result carries its premium status`() {
        let result = SpotifyAuthResult(isAuthorized: true, premium: .free)

        #expect(result.isAuthorized)
        #expect(result.premium == .free)
    }
}

struct SpotifyAuthorizationCodeTests {

    @Test func `code is read from the redirect`() throws {
        let result = SpotifyWebAuthSession.authorizationCode(from: URL(string: "beatrate://spotify-callback?code=abc&state=x"), error: nil)

        #expect(try result.get() == "abc")
    }

    @Test func `dismissing the sheet is a cancellation, not a failure`() {
        let error = ASWebAuthenticationSessionError(.canceledLogin)

        let result = SpotifyWebAuthSession.authorizationCode(from: nil, error: error)

        #expect(throws: SpotifyFailure.authCancelled) { try result.get() }
    }

    @Test func `any other sheet error fails authorization`() {
        let result = SpotifyWebAuthSession.authorizationCode(from: nil, error: URLError(.notConnectedToInternet))

        #expect(throws: SpotifyFailure.authorizationFailed) { try result.get() }
    }

    @Test(arguments: ["beatrate://spotify-callback?error=access_denied", "beatrate://spotify-callback"])
    func `redirect without a code fails authorization`(callback: String) {
        let result = SpotifyWebAuthSession.authorizationCode(from: URL(string: callback), error: nil)

        #expect(throws: SpotifyFailure.authorizationFailed) { try result.get() }
    }
}
