import Foundation
import Testing
@testable import SpotifyService

struct SpotifyTokenStoreTests {

    @Test func legacyTokensAreCarriedForwardNotDiscarded() async throws {
        let keychain = StubKeychain(legacyPair: (accessToken: "old-access", refreshToken: "old-refresh"))
        let store = SpotifyTokenStore(keychain: keychain)

        let tokens = try await #require(store.load())

        // The whole point: an existing user must not be signed out by the
        // move to single-item storage.
        #expect(tokens.accessToken == "old-access")
        #expect(tokens.refreshToken == "old-refresh")
        // No expiry existed in the old format, so force one refresh on first use.
        #expect(!tokens.isFresh())
    }

    @Test func migrationPersistsToTheNewItemAndClearsLegacyKeys() async throws {
        let keychain = StubKeychain(legacyPair: (accessToken: "old-access", refreshToken: "old-refresh"))
        let store = SpotifyTokenStore(keychain: keychain)

        _ = try await store.load()

        #expect(await keychain.savedTokenData() != nil)
        #expect(await keychain.legacyCleared)
    }

    @Test func migrationRunsOnlyOnce() async throws {
        let keychain = StubKeychain(legacyPair: (accessToken: "old-access", refreshToken: "old-refresh"))
        let store = SpotifyTokenStore(keychain: keychain)

        _ = try await store.load()
        _ = try await store.load()

        #expect(await keychain.legacyReadCount == 1)
    }

    @Test func newFormatIsReadDirectlyWithoutMigration() async throws {
        let existing = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: .distantFuture)
        let keychain = StubKeychain(tokenData: try existing.encoded())
        let store = SpotifyTokenStore(keychain: keychain)

        let tokens = try await #require(store.load())

        #expect(tokens == existing)
        #expect(await keychain.legacyReadCount == 0)
    }

    @Test func emptyKeychainYieldsNoTokens() async throws {
        let store = SpotifyTokenStore(keychain: StubKeychain())
        #expect(try await store.load() == nil)
    }
}
