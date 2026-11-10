import Foundation
import Testing
@testable import SpotifyService

@MainActor
struct SpotifyAuthorizeTests {
    private static let redirect = URL(string: "beatrate://spotify-callback")!
    private static let tokenBody = Data(#"{"access_token":"access","refresh_token":"refresh","expires_in":3600}"#.utf8)

    private func session(
        store: StubTokenStore? = nil,
        transport: StubTransport,
        presenter: StubAuthorizationPresenter?
    ) -> SpotifySession {
        // Built here, not as a default argument: an actor in a main-actor default
        // argument trips a Swift 6.4 compiler bug.
        SpotifySession(
            tokenStore: store ?? StubTokenStore(), transport: transport, clientId: "cid",
            redirectUri: Self.redirect, callbackScheme: "beatrate",
            makePresenter: { presenter }
        )
    }

    private static func form(_ request: URLRequest?) -> [String: String] {
        let body = request?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let items = URLComponents(string: "?\(body)")?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func `authorization code is exchanged for tokens that get saved`() async throws {
        let store = StubTokenStore()
        let transport = StubTransport(scripted: [.init(status: 200, body: Self.tokenBody)])
        let presenter = StubAuthorizationPresenter()

        let tokens = try await session(store: store, transport: transport, presenter: presenter).authorize()

        #expect(tokens.accessToken == "access")
        #expect(tokens.refreshToken == "refresh")
        #expect(await store.currentTokens()?.accessToken == "access")
        #expect(presenter.presented.map(\.scheme) == ["beatrate"])
        let form = Self.form(await transport.sentRequests.first)
        #expect(form["grant_type"] == "authorization_code")
        #expect(form["code"] == "auth-code")
        #expect(form["redirect_uri"] == Self.redirect.absoluteString)
        #expect(form["client_id"] == "cid")
    }

    // The verifier sent with the code must be the one the sheet's challenge came from.
    @Test func `token exchange proves the pkce challenge shown in the sheet`() async throws {
        let transport = StubTransport(scripted: [.init(status: 200, body: Self.tokenBody)])
        let presenter = StubAuthorizationPresenter()

        _ = try await session(transport: transport, presenter: presenter).authorize()

        let shown = try #require(presenter.presented.first?.url)
        let challenge = URLComponents(url: shown, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "code_challenge" }?.value
        let verifier = try #require(Self.form(await transport.sentRequests.first)["code_verifier"])
        #expect(challenge == PKCE.challenge(for: verifier))
    }

    @Test func `no window to present on fails authorization`() async {
        let transport = StubTransport()

        await #expect(throws: SpotifyFailure.authorizationFailed) {
            try await session(transport: transport, presenter: nil).authorize()
        }
        #expect(await transport.sentCount == 0)
    }

    @Test func `dismissed sheet is a cancellation and requests nothing`() async {
        let transport = StubTransport()

        await #expect(throws: SpotifyFailure.authCancelled) {
            try await session(transport: transport, presenter: StubAuthorizationPresenter(result: .failure(.authCancelled))).authorize()
        }
        #expect(await transport.sentCount == 0)
    }

    @Test func `rejected code exchange saves no tokens`() async {
        let store = StubTokenStore()
        let transport = StubTransport(scripted: [.init(status: 400)])

        await #expect(throws: SpotifyFailure.sessionExpired) {
            try await session(store: store, transport: transport, presenter: StubAuthorizationPresenter()).authorize()
        }
        #expect(await store.saveCount == 0)
    }

    // MARK: - SpotifyService

    private func service(transport: StubTransport) -> SpotifyService {
        SpotifyService(
            session: session(transport: transport, presenter: StubAuthorizationPresenter()),
            client: SpotifyClient(transport: transport, retryDelay: { _ in })
        )
    }

    @Test func `connecting reports premium from the same profile call`() async throws {
        let transport = StubTransport(scripted: [
            .init(status: 200, body: Self.tokenBody),
            .init(status: 200, body: Data(#"{"product":"premium"}"#.utf8)),
        ])

        let result = try await service(transport: transport).requestAuthorization()

        #expect(result.isAuthorized)
        #expect(result.premium == .premium)
        #expect(await transport.sentCount == 2)
    }

    // A failed check must not read as a downgrade to free.
    @Test func `failed premium check after connecting is unknown`() async throws {
        let transport = StubTransport(scripted: [
            .init(status: 200, body: Self.tokenBody),
            .init(status: 403),
        ])

        let result = try await service(transport: transport).requestAuthorization()

        #expect(result.isAuthorized)
        #expect(result.premium == .unknown)
    }
}
