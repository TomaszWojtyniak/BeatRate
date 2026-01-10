//
//  SettingsDataModel.swift
//  Settings
//
//  Created by Tomasz Wojtyniak on 09/01/2026.
//

import SwiftUI
import SplashUseCases
import Analytics
import OSLog

@MainActor
@Observable
final class SettingsDataModel {
    private let getSplashUseCase: GetSplashUseCaseProtocol

    var isLoggingOut = false
    var showLogoutConfirmation = false

    init(getSplashUseCase: GetSplashUseCaseProtocol = GetSplashUseCase()) {
        self.getSplashUseCase = getSplashUseCase
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
