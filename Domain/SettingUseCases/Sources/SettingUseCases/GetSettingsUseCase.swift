//
//  GetSettingsUseCase.swift
//  SettingUseCases
//
//  Created by Tomasz Wojtyniak on 19/02/2026.
//

import LoginUseCases
import SwiftDataManager
import MusicRepository

public protocol GetSettingsUseCaseProtocol: Sendable {
    func loadAppleMusicStatus() async throws -> Bool
    func loadSpotifyStatus() async throws -> Bool
    func fetchRecentlyPlayed() async throws
}

public actor GetSettingsUseCase: GetSettingsUseCaseProtocol {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    private let musicRepository: MusicRepositoryProtocol

    public init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared,
                musicRepository: MusicRepositoryProtocol = MusicRepository.shared) {
        self.getLoginUseCase = getLoginUseCase
        self.swiftDataManager = swiftDataManager
        self.musicRepository = musicRepository
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
}
