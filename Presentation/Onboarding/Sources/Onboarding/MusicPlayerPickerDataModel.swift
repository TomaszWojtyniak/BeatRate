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

    /// Picking a player also connects it — there is no separate "connect" step
    /// anywhere in the app.
    ///
    /// Returns true when the screen should dismiss (selection complete).
    /// The choice is **only** persisted after a successful connect — cancelling or
    /// being denied leaves `MusicPlayerManager.current` untouched so we don't strand
    /// the user on a player they have no access to.
    func select(_ player: MusicPlayer) async -> Bool {
        isProcessing = true
        pendingChoice = player
        errorMessage = nil
        defer {
            isProcessing = false
            pendingChoice = nil
        }

        do {
            guard try await ensureConnected(player) else {
                errorMessage = "\(player.displayName) access wasn't granted."
                return false
            }
        } catch {
            Logger.onboarding.error("\(player.displayName) connect failed: \(error)")
            errorMessage = "Couldn't connect \(player.displayName). Please try again."
            return false
        }

        return await persist(player)
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

    private func ensureConnected(_ player: MusicPlayer) async throws -> Bool {
        switch player {
        case .appleMusic:
            // Unconditional: when authorization is already granted this returns
            // straight away with no prompt, and it refreshes the stored
            // subscription flag while it's there.
            return try await setSettingsUseCase.connectAppleMusic()

        case .spotify:
            // Short-circuited, unlike Apple Music — `connectSpotify()` launches the
            // full OAuth web flow every time it's called.
            let alreadyConnected = (try? await getSettingsUseCase.loadSpotifyStatus()) ?? false
            if alreadyConnected { return true }
            return try await setSettingsUseCase.connectSpotify()
        }
    }
}
