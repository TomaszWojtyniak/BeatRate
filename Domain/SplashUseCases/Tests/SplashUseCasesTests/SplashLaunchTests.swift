import Models
import MusicRepository
import SpotifyService
import Testing
@testable import SplashUseCases

@MainActor
struct SplashLaunchTests {

    @Test func `launch data comes from the repositories and cache`() async throws {
        let harness = SplashTestHarness()
        harness.home.sections = [HomeSection(name: "New", albums: [])]
        harness.music.authorization = MusicAuthorizationInfo(isAuthorized: false, hasSubscription: false)
        harness.music.authorizationDetermined = false
        harness.music.spotifyConnection = .notAllowlisted
        let useCase = harness.useCase

        #expect(try await useCase.fetchHomeSections().map(\.name) == ["New"])
        #expect(try await useCase.getCachedSections().isEmpty)
        try await useCase.cacheSections([])
        #expect(await !useCase.isCacheValid())
        #expect(await !useCase.authorizeMusicKit())
        #expect(await !useCase.isMusicKitAuthorizationDetermined())
        #expect(await useCase.verifySpotifyConnection() == .notAllowlisted)
        #expect(await useCase.getCurrentNonce() == "nonce")
    }

    // MARK: - Spotify premium

    @Test func `changed premium status is written to the profile`() async {
        let harness = SplashTestHarness()
        harness.signIn()
        harness.loginUseCases.profiles = ["u": FirebaseUserProfile(email: "a@b.c", firstName: nil, lastName: nil, hasSpotifyPremium: false)]

        await harness.useCase.refreshSpotifyPremium(.premium)

        #expect(harness.login.savedProfiles.first?.profile.hasSpotifyPremium == true)
        #expect(harness.login.savedProfiles.first?.profile.email == "a@b.c")
    }

    @Test func `unchanged premium status is not rewritten`() async {
        let harness = SplashTestHarness()
        harness.signIn()
        harness.loginUseCases.profiles = ["u": FirebaseUserProfile(email: nil, firstName: nil, lastName: nil, hasSpotifyPremium: true)]

        await harness.useCase.refreshSpotifyPremium(.premium)

        #expect(harness.login.savedProfiles.isEmpty)
    }

    @Test func `unknown premium status or a guest writes nothing`() async {
        let harness = SplashTestHarness()

        await harness.useCase.refreshSpotifyPremium(.free)
        harness.signIn()
        await harness.useCase.refreshSpotifyPremium(.unknown)

        #expect(harness.login.savedProfiles.isEmpty)
    }

    @Test func `failed premium refresh is swallowed`() async {
        let harness = SplashTestHarness()
        harness.signIn()
        harness.loginUseCases.failsToReadProfile = true

        await harness.useCase.refreshSpotifyPremium(.premium)

        #expect(harness.login.savedProfiles.isEmpty)
    }

    // MARK: - Main music player

    @Test func `guest or unreadable user has no player to hydrate`() async {
        let harness = SplashTestHarness()
        #expect(await !harness.useCase.hydrateMainMusicPlayer())

        harness.cache.failsToReadUserId = true
        #expect(await !harness.useCase.hydrateMainMusicPlayer())
    }

    @Test func `locally saved player is hydrated`() async {
        let harness = SplashTestHarness()
        harness.signIn()
        harness.defaults.setMainMusicPlayer(.spotify, for: "u")

        #expect(await harness.useCase.hydrateMainMusicPlayer())
        #expect(harness.player.current == .spotify)
    }

    @Test func `player from the profile is saved locally`() async {
        let harness = SplashTestHarness()
        harness.signIn()
        harness.loginUseCases.profiles = ["u": FirebaseUserProfile(email: nil, firstName: nil, lastName: nil, mainMusicPlayer: "appleMusic")]

        #expect(await harness.useCase.hydrateMainMusicPlayer())
        #expect(harness.defaults.mainMusicPlayer(for: "u") == .appleMusic)
    }

    // A cold-launch network blip must not bounce the user back into the picker.
    @Test func `unreachable profile skips the picker`() async {
        let harness = SplashTestHarness()
        harness.signIn()
        harness.loginUseCases.failsToReadProfile = true

        #expect(await harness.useCase.hydrateMainMusicPlayer())
    }

    @Test func `user who never chose a player gets the picker`() async {
        let harness = SplashTestHarness()
        harness.signIn()

        #expect(await !harness.useCase.hydrateMainMusicPlayer())
    }
}
