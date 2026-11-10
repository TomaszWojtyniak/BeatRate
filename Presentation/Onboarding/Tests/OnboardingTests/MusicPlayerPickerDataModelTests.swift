import Analytics
import CoreApp
import Foundation
import Models
import struct MusicKit.MusicAuthorization
import Testing
@testable import Onboarding

@MainActor
struct MusicPlayerPickerDataModelTests {
    private let useCases = StubSettingsUseCases()
    private let player = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: UserDefaults(suiteName: "OnboardingTests.\(UUID())")!))
    private let backend: StubAnalyticsBackend
    private let model: MusicPlayerPickerDataModel

    init() {
        let analytics: AnalyticsManager
        (analytics, backend) = makeAnalytics()
        model = MusicPlayerPickerDataModel(
            mode: .onboarding, setSettingsUseCase: useCases, getSettingsUseCase: useCases,
            musicPlayerManager: player, analyticsManager: analytics, appleMusicStatus: { .denied }
        )
    }

    @Test(arguments: MusicPlayer.allCases)
    func `connected player is saved and closes the picker`(choice: MusicPlayer) async {
        #expect(await model.select(choice))
        #expect(useCases.savedPlayers == [choice])
        #expect(model.errorMessage == nil)
        #expect(!model.isProcessing)
        #expect(model.pendingChoice == nil)
    }

    // Spotify's connect launches a full OAuth sheet, so an existing session skips it.
    @Test func `already connected spotify is not authorized again`() async {
        useCases.spotifyAlreadyConnected = true

        #expect(await model.select(.spotify))
        #expect(useCases.spotifyConnectCount == 0)
    }

    // A denied player must not become the user's choice.
    @Test func `denied apple music offers settings and saves nothing`() async {
        useCases.appleMusicConnect = .success(false)

        #expect(await !model.select(.appleMusic))
        #expect(model.errorMessage != nil)
        #expect(model.showsOpenSettings)
        #expect(useCases.savedPlayers.isEmpty)
    }

    @Test func `denied spotify shows an error without the settings shortcut`() async {
        useCases.spotifyConnect = .success(false)

        #expect(await !model.select(.spotify))
        #expect(model.errorMessage != nil)
        #expect(!model.showsOpenSettings)
    }

    @Test func `failed connection shows an error`() async {
        useCases.spotifyConnect = .failure(StubError())

        #expect(await !model.select(.spotify))
        #expect(model.errorMessage != nil)
        #expect(useCases.savedPlayers.isEmpty)
    }

    @Test func `failed save shows an error and keeps the picker open`() async {
        useCases.failsToSavePlayer = true

        #expect(await !model.select(.appleMusic))
        #expect(model.errorMessage != nil)
    }

    @Test func `current player and events come through the model`() {
        player.set(.spotify, for: "u")

        model.track(.permissionContinueTap)

        #expect(model.currentPlayer == .spotify)
        #expect(model.mode == .onboarding)
        #expect(backend.logged(.permissionContinueTap))
    }

    @Test func `choosing a player is tracked with the picker mode`() async {
        #expect(await model.choose(.spotify))

        #expect(useCases.savedPlayers == [.spotify])
        #expect(backend.logged(.musicPlayerSelected(player: "spotify", mode: "onboarding")))
    }

    // Settings pushes the picker; onboarding is swapped out by the app instead.
    @Test(arguments: [(MusicPlayerPickerMode.onboarding, false), (.change, true)])
    func `only the settings picker dismisses itself`(mode: MusicPlayerPickerMode, dismisses: Bool) {
        let model = MusicPlayerPickerDataModel(mode: mode, setSettingsUseCase: useCases, getSettingsUseCase: useCases, musicPlayerManager: player)

        #expect(model.dismissesOnCompletion == dismisses)
    }
}
