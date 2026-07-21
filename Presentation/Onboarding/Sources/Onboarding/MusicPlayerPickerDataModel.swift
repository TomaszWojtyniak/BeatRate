//
//  MusicPlayerPickerDataModel.swift
//  Onboarding
//

import SwiftUI
import Models
import CoreApp
import SettingUseCases
import Analytics
import OSLog

@MainActor
@Observable
final class MusicPlayerPickerDataModel {
    let mode: MusicPlayerPickerMode

    var isProcessing: Bool = false
    var pendingChoice: MusicPlayer?
    var errorMessage: String?

    private let setSettingsUseCase: SetSettingsUseCaseProtocol
    private let getSettingsUseCase: GetSettingsUseCaseProtocol
    private let musicPlayerManager: MusicPlayerManager

    init(mode: MusicPlayerPickerMode,
         setSettingsUseCase: SetSettingsUseCaseProtocol = SetSettingsUseCase(),
         getSettingsUseCase: GetSettingsUseCaseProtocol = GetSettingsUseCase(),
         musicPlayerManager: MusicPlayerManager = .shared) {
        self.mode = mode
        self.setSettingsUseCase = setSettingsUseCase
        self.getSettingsUseCase = getSettingsUseCase
        self.musicPlayerManager = musicPlayerManager
    }

    /// The currently selected player, surfaced for the view so it doesn't reach for
    /// the manager itself.
    var currentPlayer: MusicPlayer? {
        musicPlayerManager.current
    }

    /// Returns true when the screen should dismiss (selection complete).
    /// For Spotify, the choice is **only** persisted after a successful OAuth — cancelling
    /// or failing the connect leaves `MusicPlayerManager.current` untouched so we don't
    /// strand the user with a player selection that has no valid token.
    func select(_ player: MusicPlayer) async -> Bool {
        isProcessing = true
        pendingChoice = player
        errorMessage = nil
        defer {
            isProcessing = false
            pendingChoice = nil
        }

        switch player {
        case .appleMusic:
            return await persist(player)

        case .spotify:
            do {
                let connected = try await ensureSpotifyConnected()
                guard connected else {
                    errorMessage = "Spotify connection was cancelled."
                    return false
                }
            } catch {
                Logger.onboarding.error("Spotify connect failed: \(error)")
                errorMessage = "Couldn't connect Spotify. Please try again."
                return false
            }
            return await persist(player)
        }
    }

    private func persist(_ player: MusicPlayer) async -> Bool {
        do {
            try await setSettingsUseCase.setMainMusicPlayer(player)
            return true
        } catch {
            Logger.onboarding.error("Failed to set main music player: \(error)")
            errorMessage = "Couldn't save your choice. Please try again."
            return false
        }
    }

    private func ensureSpotifyConnected() async throws -> Bool {
        let alreadyConnected = (try? await getSettingsUseCase.loadSpotifyStatus()) ?? false
        if alreadyConnected { return true }
        return try await setSettingsUseCase.connectSpotify()
    }
}
