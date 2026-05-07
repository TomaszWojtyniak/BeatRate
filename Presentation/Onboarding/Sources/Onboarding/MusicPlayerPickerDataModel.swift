//
//  MusicPlayerPickerDataModel.swift
//  Onboarding
//

import SwiftUI
import Models
import CoreApp
import SettingUseCases
import OSLog

private let logger = Logger(subsystem: "com.beatrate.app", category: "onboarding")

@MainActor
@Observable
final class MusicPlayerPickerDataModel {
    let mode: MusicPlayerPickerMode

    var isProcessing: Bool = false
    var pendingChoice: MusicPlayer?
    var errorMessage: String?

    private let setSettingsUseCase: SetSettingsUseCaseProtocol
    private let getSettingsUseCase: GetSettingsUseCaseProtocol

    init(mode: MusicPlayerPickerMode,
         setSettingsUseCase: SetSettingsUseCaseProtocol = SetSettingsUseCase(),
         getSettingsUseCase: GetSettingsUseCaseProtocol = GetSettingsUseCase()) {
        self.mode = mode
        self.setSettingsUseCase = setSettingsUseCase
        self.getSettingsUseCase = getSettingsUseCase
    }

    /// Returns true when the screen should dismiss (selection complete).
    func select(_ player: MusicPlayer) async -> Bool {
        isProcessing = true
        pendingChoice = player
        errorMessage = nil
        defer {
            isProcessing = false
            pendingChoice = nil
        }

        do {
            try await setSettingsUseCase.setMainMusicPlayer(player)
        } catch {
            logger.error("Failed to set main music player: \(error)")
            errorMessage = "Couldn't save your choice. Please try again."
            return false
        }

        switch player {
        case .appleMusic:
            return true

        case .spotify:
            do {
                let connected = try await ensureSpotifyConnected()
                if !connected {
                    errorMessage = "Spotify connection was cancelled."
                }
                return connected
            } catch {
                logger.error("Spotify connect failed: \(error)")
                errorMessage = "Couldn't connect Spotify. Please try again."
                return false
            }
        }
    }

    private func ensureSpotifyConnected() async throws -> Bool {
        let alreadyConnected = (try? await getSettingsUseCase.loadSpotifyStatus()) ?? false
        if alreadyConnected { return true }
        return try await setSettingsUseCase.connectSpotify()
    }
}
