//
//  SettingsDataModel.swift
//  Settings
//
//  Created by Tomasz Wojtyniak on 09/01/2026.
//

import SwiftUI
import SplashUseCases
import SettingUseCases
import Analytics
import OSLog
import Models

@MainActor
@Observable
final class SettingsDataModel {
    private let getSplashUseCase: GetSplashUseCaseProtocol
    private let getSettingsUseCase: GetSettingsUseCaseProtocol
    private let setSettingsUseCase: SetSettingsUseCaseProtocol

    var isLoggingOut = false
    var showLogoutConfirmation = false
    var isAppleMusicConnected = false
    var isConnectingAppleMusic = false

    init(getSplashUseCase: GetSplashUseCaseProtocol = GetSplashUseCase(),
         getSettingsUseCase: GetSettingsUseCaseProtocol = GetSettingsUseCase(),
         setSettingsUseCase: SetSettingsUseCaseProtocol = SetSettingsUseCase()) {
        self.getSplashUseCase = getSplashUseCase
        self.getSettingsUseCase = getSettingsUseCase
        self.setSettingsUseCase = setSettingsUseCase
    }

    func loadUserProfile() async {
        do {
            isAppleMusicConnected = try await getSettingsUseCase.loadAppleMusicStatus()
            Logger.settings.info("Loaded user profile, Apple Music connected: \(self.isAppleMusicConnected)")
        } catch {
            Logger.settings.error("Failed to load user profile: \(error)")
        }
    }

    func connectAppleMusic() async {
        isConnectingAppleMusic = true
        defer { isConnectingAppleMusic = false }

        do {
            isAppleMusicConnected = try await setSettingsUseCase.connectAppleMusic()
        } catch {
            Logger.settings.error("Failed to connect Apple Music: \(error)")
        }
    }

    func logout() async throws {
        isLoggingOut = true
        defer { isLoggingOut = false }

        do {
            try await getSplashUseCase.logout()
            Logger.settings.info("Logout successful")
        } catch {
            Logger.settings.error("Logout failed: \(error)")
            throw error
        }
    }
}
