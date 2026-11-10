import CoreApp
import Models
import MusicRepository
import SpotifyService
import SwiftDataManager
import Testing
@testable import SettingUseCases

@MainActor
struct SetSettingsUseCaseTests {
    private let login = StubLoginUseCases()
    private let music = StubMusicRepository()
    private let cache = SwiftDataManager.inMemory()
    private let player: MusicPlayerManager
    private let defaults: UserDefaultsManager

    private static let existing = FirebaseUserProfile(
        email: "a@b.c", firstName: "Ann", lastName: "Lee",
        hasAppleMusicSubscription: false, hasSpotifyConnection: false, hasSpotifyPremium: true, mainMusicPlayer: "spotify"
    )

    init() {
        (player, defaults) = makePlayerManager()
    }

    private var useCase: SetSettingsUseCase {
        SetSettingsUseCase(musicRepository: music, getLoginUseCase: login, setLoginUseCase: login, swiftDataManager: cache, musicPlayerManager: player)
    }

    private func signIn() async throws {
        try await cache.setUserLoggedIn(userId: "u")
        login.profiles = ["u": Self.existing]
    }

    // MARK: - Apple Music

    @Test func `connecting apple music records the subscription and keeps the rest of the profile`() async throws {
        try await signIn()
        music.authorization = MusicAuthorizationInfo(isAuthorized: true, hasSubscription: true)

        #expect(try await useCase.connectAppleMusic())

        let saved = try #require(login.savedProfiles.first?.profile)
        #expect(saved.hasAppleMusicSubscription == true)
        #expect(saved.email == "a@b.c")
        #expect(saved.hasSpotifyPremium == true)
        #expect(saved.mainMusicPlayer == "spotify")
    }

    @Test func `refused apple music access saves nothing`() async throws {
        try await signIn()
        music.authorization = MusicAuthorizationInfo(isAuthorized: false, hasSubscription: false)

        #expect(try await !useCase.connectAppleMusic())
        #expect(login.savedProfiles.isEmpty)
    }

    @Test func `apple music cannot be connected without a signed in user`() async throws {
        #expect(try await !useCase.connectAppleMusic())
        #expect(login.savedProfiles.isEmpty)
    }

    // MARK: - Spotify

    @Test func `connecting spotify marks the connection and its premium status`() async throws {
        try await signIn()
        music.spotifyAuthorization = .success(SpotifyAuthorizationInfo(isAuthorized: true, premium: .free))

        #expect(try await useCase.connectSpotify())

        let saved = try #require(login.savedProfiles.first?.profile)
        #expect(saved.hasSpotifyConnection == true)
        #expect(saved.hasSpotifyPremium == false)
        #expect(saved.firstName == "Ann")
    }

    // An unknown check must not read as a downgrade.
    @Test func `unknown premium status keeps the stored one`() async throws {
        try await signIn()
        music.spotifyAuthorization = .success(SpotifyAuthorizationInfo(isAuthorized: true, premium: .unknown))

        _ = try await useCase.connectSpotify()

        #expect(login.savedProfiles.first?.profile.hasSpotifyPremium == true)
    }

    @Test func `refused spotify access or a guest saves nothing`() async throws {
        music.spotifyAuthorization = .success(SpotifyAuthorizationInfo(isAuthorized: true, premium: .premium))
        #expect(try await !useCase.connectSpotify())

        try await signIn()
        music.spotifyAuthorization = .success(SpotifyAuthorizationInfo(isAuthorized: false, premium: .unknown))
        #expect(try await !useCase.connectSpotify())

        #expect(login.savedProfiles.isEmpty)
    }

    @Test func `spotify sign in failure is passed on`() async throws {
        music.spotifyAuthorization = .failure(StubError())

        await #expect(throws: StubError.self) { try await useCase.connectSpotify() }
    }

    // MARK: - Main player

    @Test func `chosen player is stored locally and synced to the profile`() async throws {
        try await signIn()

        try await useCase.setMainMusicPlayer(.appleMusic)

        #expect(player.current == .appleMusic)
        #expect(defaults.mainMusicPlayer(for: "u") == .appleMusic)
        #expect(login.savedProfiles.first?.profile.mainMusicPlayer == "appleMusic")
        #expect(login.savedProfiles.first?.profile.email == "a@b.c")
    }

    // Local storage is the source of truth; a Firebase hiccup must not undo the choice.
    @Test func `failed profile sync keeps the local choice`() async throws {
        try await signIn()
        login.failsToSaveProfile = true

        try await useCase.setMainMusicPlayer(.spotify)

        #expect(player.current == .spotify)
    }

    @Test func `guest cannot choose a player`() async throws {
        try await useCase.setMainMusicPlayer(.spotify)

        #expect(player.current == nil)
        #expect(login.savedProfiles.isEmpty)
    }
}
