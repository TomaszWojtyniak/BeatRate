//
//  GetSettingsUseCase.swift
//  SettingUseCases
//
//  Created by Tomasz Wojtyniak on 19/02/2026.
//

import LoginUseCases
import SwiftDataManager
import MusicRepository
import CoreApp
import Models

public protocol GetSettingsUseCaseProtocol: Sendable {
    func loadAppleMusicStatus() async throws -> Bool
    func loadSpotifyStatus() async throws -> Bool
    func fetchRecentlyPlayed() async throws
    func getMainMusicPlayer() async throws -> MusicPlayer?
}

public actor GetSettingsUseCase: GetSettingsUseCaseProtocol {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    private let musicRepository: MusicRepositoryProtocol
    private let musicPlayerManager: MusicPlayerManager
    private let userDefaultsManager: UserDefaultsManager

    public init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared,
                musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
                musicPlayerManager: MusicPlayerManager = .shared,
                userDefaultsManager: UserDefaultsManager = .shared) {
        self.getLoginUseCase = getLoginUseCase
        self.swiftDataManager = swiftDataManager
        self.musicRepository = musicRepository
        self.musicPlayerManager = musicPlayerManager
        self.userDefaultsManager = userDefaultsManager
    }

    public func loadAppleMusicStatus() async throws -> Bool {
        guard let userId = try await swiftDataManager.getCurrentUserId() else {
            return false
        }
        let profile = try await getLoginUseCase.getUserProfile(userId: userId)
        let firebaseFlag = profile?.hasAppleMusicSubscription == true
        let localAuth = await musicRepository.isAppleMusicAuthorized()
        return firebaseFlag && localAuth
    }

    public func loadSpotifyStatus() async throws -> Bool {
        guard let userId = try await swiftDataManager.getCurrentUserId() else {
            return false
        }
        let profile = try await getLoginUseCase.getUserProfile(userId: userId)
        let firebaseFlag = profile?.hasSpotifyConnection == true
        let hasToken = await musicRepository.isSpotifyTokenAvailable()
        return firebaseFlag && hasToken
    }
    
    public func fetchRecentlyPlayed() async throws {
        try await musicRepository.fetchSpotifyRecentlyPlayed()
    }

    /// Returns the user's main music player.
    /// Reads UserDefaults first; if nil, falls back to the Firebase user profile and
    /// hydrates UserDefaults + `musicPlayerManager` so subsequent reads are local.
    public func getMainMusicPlayer() async throws -> MusicPlayer? {
        guard let userId = try await swiftDataManager.getCurrentUserId() else {
            return nil
        }

        if let local = userDefaultsManager.mainMusicPlayer(for: userId) {
            await musicPlayerManager.hydrate(for: userId)
            return local
        }

        let profile = try await getLoginUseCase.getUserProfile(userId: userId)
        guard let raw = profile?.mainMusicPlayer,
              let player = MusicPlayer(rawValue: raw) else {
            return nil
        }

        await musicPlayerManager.set(player, for: userId)
        return player
    }
}
