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
import CoreApp
import OSLog
import Models
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
final class SettingsDataModel {
    private let getSplashUseCase: GetSplashUseCaseProtocol
    private let getSettingsUseCase: GetSettingsUseCaseProtocol
    private let musicPlayerManager: MusicPlayerManager

    /// The user's main player, surfaced for the view so it doesn't reach for the
    /// manager itself.
    var mainMusicPlayer: MusicPlayer? {
        musicPlayerManager.current
    }

    var isLoggingOut = false
    var showLogoutConfirmation = false
    var isDeletingAccount = false
    var showDeleteAccountSheet = false
    var isSpotifyConnected = false
    /// Drives the footer under the player row; nil means nothing to report.
    var spotifyNotice: String?

    init(getSplashUseCase: GetSplashUseCaseProtocol = GetSplashUseCase(),
         getSettingsUseCase: GetSettingsUseCaseProtocol = GetSettingsUseCase(),
         musicPlayerManager: MusicPlayerManager = .shared) {
        self.getSplashUseCase = getSplashUseCase
        self.getSettingsUseCase = getSettingsUseCase
        self.musicPlayerManager = musicPlayerManager
    }

    func loadUserProfile() async {
        do {
            isSpotifyConnected = try await getSettingsUseCase.loadSpotifyStatus()
            await refreshSpotifyNotice()
            Logger.settings.info("Loaded user profile, Spotify: \(self.isSpotifyConnected)")
        } catch {
            Logger.settings.error("Failed to load user profile: \(error)")
        }
    }

    /// Only meaningful once we hold credentials. A transient failure reports
    /// nothing — the user does not need to know the network hiccuped.
    private func refreshSpotifyNotice() async {
        guard isSpotifyConnected else {
            spotifyNotice = nil
            return
        }
        switch await getSplashUseCase.verifySpotifyConnection() {
        case .needsReauth, .notConnected:
            spotifyNotice = "Your Spotify session expired. Pick Spotify again to reconnect."
        case .connected, .unavailable, .notAllowlisted:
            spotifyNotice = nil
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

    func getCurrentNonce() async -> String {
        await getSplashUseCase.getCurrentNonce()
    }

    func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    func deleteAccount(authResult: ASAuthorization) async throws {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await getSplashUseCase.deleteAccount(authResult: authResult)
            Logger.settings.info("Account deletion successful")
        } catch {
            Logger.settings.error("Account deletion failed: \(error)")
            throw error
        }
    }
}
