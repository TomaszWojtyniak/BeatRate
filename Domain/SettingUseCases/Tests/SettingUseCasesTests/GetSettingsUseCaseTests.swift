import CoreApp
import Models
import SwiftDataManager
import Testing
@testable import SettingUseCases

@MainActor
struct GetSettingsUseCaseTests {
    private let login = StubLoginUseCases()
    private let music = StubMusicRepository()
    private let cache = SwiftDataManager.inMemory()
    private let player: MusicPlayerManager
    private let defaults: UserDefaultsManager

    init() {
        (player, defaults) = makePlayerManager()
    }

    private var useCase: GetSettingsUseCase {
        GetSettingsUseCase(getLoginUseCase: login, swiftDataManager: cache, musicRepository: music, musicPlayerManager: player, userDefaultsManager: defaults)
    }

    @Test func `guest has nothing connected and no player`() async throws {
        #expect(try await !useCase.loadAppleMusicStatus())
        #expect(try await !useCase.loadSpotifyStatus())
        #expect(try await useCase.getMainMusicPlayer() == nil)
    }

    @Test(arguments: [(true, true, true), (true, false, false), (false, true, false)])
    func `apple music counts as connected only with the profile flag and local access`(flag: Bool, authorized: Bool, expected: Bool) async throws {
        try await cache.setUserLoggedIn(userId: "u")
        login.profiles = ["u": FirebaseUserProfile(email: nil, firstName: nil, lastName: nil, hasAppleMusicSubscription: flag)]
        music.appleMusicAuthorized = authorized

        #expect(try await useCase.loadAppleMusicStatus() == expected)
    }

    @Test(arguments: [(true, true, true), (true, false, false), (false, true, false)])
    func `spotify counts as connected only with the profile flag and stored credentials`(flag: Bool, session: Bool, expected: Bool) async throws {
        try await cache.setUserLoggedIn(userId: "u")
        login.profiles = ["u": FirebaseUserProfile(email: nil, firstName: nil, lastName: nil, hasSpotifyConnection: flag)]
        music.storedSpotifySession = session

        #expect(try await useCase.loadSpotifyStatus() == expected)
    }

    @Test func `locally saved player wins without asking firebase`() async throws {
        try await cache.setUserLoggedIn(userId: "u")
        defaults.setMainMusicPlayer(.spotify, for: "u")
        login.failsToReadProfile = true

        #expect(try await useCase.getMainMusicPlayer() == .spotify)
        #expect(player.current == .spotify)
    }

    @Test func `player from the firebase profile is saved locally`() async throws {
        try await cache.setUserLoggedIn(userId: "u")
        login.profiles = ["u": FirebaseUserProfile(email: nil, firstName: nil, lastName: nil, mainMusicPlayer: "appleMusic")]

        #expect(try await useCase.getMainMusicPlayer() == .appleMusic)
        #expect(defaults.mainMusicPlayer(for: "u") == .appleMusic)
        #expect(player.current == .appleMusic)
    }

    @Test(arguments: [nil, "winamp"] as [String?])
    func `missing or unknown player in the profile means none chosen`(raw: String?) async throws {
        try await cache.setUserLoggedIn(userId: "u")
        login.profiles = ["u": FirebaseUserProfile(email: nil, firstName: nil, lastName: nil, mainMusicPlayer: raw)]

        #expect(try await useCase.getMainMusicPlayer() == nil)
    }
}
