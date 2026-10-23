import Foundation
import Security
import Testing
@testable import CoreApp

@MainActor
struct KeychainManagerTests {
    private let backend = FakeKeychainBackend()
    private var keychain: KeychainManager { KeychainManager(backend: backend) }

    @Test func `apple user id round trips`() async throws {
        let keychain = keychain

        try await keychain.saveAppleUserID("apple-1")

        #expect(try await keychain.loadAppleUserID() == "apple-1")
    }

    @Test func `saving again updates the existing item in place`() async throws {
        let keychain = keychain

        try await keychain.saveAppleUserID("old")
        try await keychain.saveAppleUserID("new")

        #expect(try await keychain.loadAppleUserID() == "new")
    }

    @Test func `missing item loads as nil`() async throws {
        #expect(try await keychain.loadAppleUserID() == nil)
        #expect(try await keychain.loadSpotifyTokens() == nil)
    }

    @Test func `deleting the apple user id removes it and tolerates a missing item`() async throws {
        let keychain = keychain
        try await keychain.saveAppleUserID("apple-1")

        try await keychain.deleteAppleUserID()
        try await keychain.deleteAppleUserID()

        #expect(try await keychain.loadAppleUserID() == nil)
    }

    @Test func `spotify tokens round trip`() async throws {
        let keychain = keychain
        let tokens = Data("{}".utf8)

        try await keychain.saveSpotifyTokens(tokens)

        #expect(try await keychain.loadSpotifyTokens() == tokens)
    }

    @Test func `deleting spotify tokens also removes the legacy pair`() async throws {
        let keychain = keychain
        backend.configure {
            $0.items["spotifyTokens"] = Data("{}".utf8)
            $0.items["spotifyAccessToken"] = Data("a".utf8)
            $0.items["spotifyRefreshToken"] = Data("r".utf8)
        }

        try await keychain.deleteSpotifyTokens()

        #expect(backend.item("spotifyTokens") == nil)
        #expect(try await keychain.loadLegacySpotifyTokenPair() == nil)
    }

    @Test(arguments: [Data("r".utf8), nil] as [Data?])
    func `legacy token pair is read with or without a refresh token`(refreshToken: Data?) async throws {
        backend.configure {
            $0.items["spotifyAccessToken"] = Data("a".utf8)
            $0.items["spotifyRefreshToken"] = refreshToken
        }

        let pair = try #require(try await keychain.loadLegacySpotifyTokenPair())

        #expect(pair.accessToken == "a")
        #expect(pair.refreshToken == refreshToken.map { String(decoding: $0, as: UTF8.self) })
    }

    @Test func `deleting legacy tokens leaves the current token set alone`() async throws {
        let keychain = keychain
        backend.configure {
            $0.items["spotifyTokens"] = Data("{}".utf8)
            $0.items["spotifyAccessToken"] = Data("a".utf8)
        }

        try await keychain.deleteLegacySpotifyTokens()

        #expect(try await keychain.loadLegacySpotifyTokenPair() == nil)
        #expect(backend.item("spotifyTokens") != nil)
    }

    @Test func `failed update throws save failed`() async {
        backend.configure { $0.forcedUpdateStatus = errSecInteractionNotAllowed }

        await #expect(throws: KeychainError.saveFailed) { try await keychain.saveAppleUserID("x") }
    }

    @Test func `failed insert throws save failed`() async {
        backend.configure { $0.forcedAddStatus = errSecDuplicateItem }

        await #expect(throws: KeychainError.saveFailed) { try await keychain.saveAppleUserID("x") }
    }

    @Test func `failed read throws load failed`() async {
        backend.configure { $0.forcedCopyStatus = errSecInteractionNotAllowed }

        await #expect(throws: KeychainError.loadFailed) { try await keychain.loadAppleUserID() }
    }

    @Test func `non data result throws unexpected data`() async {
        backend.configure {
            $0.forcedCopyStatus = errSecSuccess
            $0.forcedCopyResult = NSNumber(value: 1)
        }

        await #expect(throws: KeychainError.unexpectedData) { try await keychain.loadSpotifyTokens() }
    }

    @Test func `non utf8 data throws unexpected data`() async {
        backend.configure { $0.items["appleUserID"] = Data([0xFF, 0xFE]) }

        await #expect(throws: KeychainError.unexpectedData) { try await keychain.loadAppleUserID() }
    }

    @Test func `failed delete throws delete failed`() async {
        backend.configure { $0.forcedDeleteStatus = errSecInteractionNotAllowed }

        await #expect(throws: KeychainError.deleteFailed) { try await keychain.deleteAppleUserID() }
    }
}
