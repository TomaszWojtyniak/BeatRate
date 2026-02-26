//
//  SetSettingsUseCase.swift
//  SettingUseCases
//
//  Created by Tomasz Wojtyniak on 19/02/2026.
//

import MusicRepository
import LoginUseCases
import SwiftDataManager
import Models
import Analytics

public protocol SetSettingsUseCaseProtocol: Sendable {
    func connectAppleMusic() async throws -> Bool
}

public actor SetSettingsUseCase: SetSettingsUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let setLoginUseCase: SetLoginUseCaseProtocol
    private let swiftDataManager: SwiftDataManagerProtocol

    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
                getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
                setLoginUseCase: SetLoginUseCaseProtocol = SetLoginUseCase(),
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.musicRepository = musicRepository
        self.getLoginUseCase = getLoginUseCase
        self.setLoginUseCase = setLoginUseCase
        self.swiftDataManager = swiftDataManager
    }

    public func connectAppleMusic() async throws -> Bool {
        let authResult = await musicRepository.requestMusicAuthorization()

        guard await authResult.isAuthorized else {
            Logger.settings.info("Apple Music authorization denied")
            return false
        }

        guard let userId = try await swiftDataManager.getCurrentUserId() else {
            Logger.settings.error("No user ID found when saving Apple Music status")
            return false
        }

        let hasSubscription = await authResult.hasSubscription

        let existingProfile = try await getLoginUseCase.getUserProfile(userId: userId)
        let updatedProfile = FirebaseUserProfile(
            email: existingProfile?.email,
            firstName: existingProfile?.firstName,
            lastName: existingProfile?.lastName,
            hasAppleMusicSubscription: hasSubscription
        )

        try await setLoginUseCase.saveUserProfile(userId: userId, profile: updatedProfile)
        Logger.settings.info("Apple Music connected, has subscription: \(hasSubscription)")
        return true
    }
}
