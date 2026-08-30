import Foundation
@testable import SpotifyService

/// Returns scripted responses in order and records what it was asked to send.
actor StubTransport: SpotifyTransport {
    struct Scripted {
        let status: Int
        let body: Data
        let headers: [String: String]

        init(status: Int, body: Data = Data("{}".utf8), headers: [String: String] = [:]) {
            self.status = status
            self.body = body
            self.headers = headers
        }
    }

    private var scripted: [Scripted]
    private var transportError: Error?
    private(set) var sentRequests: [URLRequest] = []

    init(scripted: [Scripted] = [], transportError: Error? = nil) {
        self.scripted = scripted
        self.transportError = transportError
    }

    var sentCount: Int { sentRequests.count }

    func authorizationHeaders() -> [String?] {
        sentRequests.map { $0.value(forHTTPHeaderField: "Authorization") }
    }

    nonisolated func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await record(request)
    }

    private func record(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sentRequests.append(request)
        if let transportError { throw transportError }
        guard !scripted.isEmpty else {
            fatalError("StubTransport ran out of scripted responses")
        }
        let next = scripted.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.status,
            httpVersion: nil,
            headerFields: next.headers
        )!
        return (next.body, response)
    }
}

/// In-memory token store. Records clears so tests can assert that a transient
/// failure never signs the user out.
actor StubTokenStore: SpotifyTokenStoring {
    private var tokens: SpotifyTokens?
    private(set) var clearCount = 0
    private(set) var saveCount = 0

    init(tokens: SpotifyTokens? = nil) {
        self.tokens = tokens
    }

    func load() async throws -> SpotifyTokens? { tokens }

    func save(_ tokens: SpotifyTokens) async throws {
        self.tokens = tokens
        saveCount += 1
    }

    func clear() async throws {
        tokens = nil
        clearCount += 1
    }

    func currentTokens() -> SpotifyTokens? { tokens }
}

/// In-memory stand-in for the Keychain, so the legacy-token migration can be
/// exercised without touching the real one.
actor StubKeychain: SpotifyKeychain {
    private var tokenData: Data?
    private var legacyPair: (accessToken: String, refreshToken: String?)?
    private(set) var legacyReadCount = 0
    private(set) var legacyCleared = false

    init(tokenData: Data? = nil, legacyPair: (accessToken: String, refreshToken: String?)? = nil) {
        self.tokenData = tokenData
        self.legacyPair = legacyPair
    }

    func savedTokenData() -> Data? { tokenData }

    func loadSpotifyTokens() async throws -> Data? { tokenData }

    func saveSpotifyTokens(_ data: Data) async throws { tokenData = data }

    func deleteSpotifyTokens() async throws {
        tokenData = nil
        legacyPair = nil
        legacyCleared = true
    }

    func loadLegacySpotifyTokenPair() async throws -> (accessToken: String, refreshToken: String?)? {
        legacyReadCount += 1
        return legacyPair
    }

    func deleteLegacySpotifyTokens() async throws {
        legacyPair = nil
        legacyCleared = true
    }
}
