//
//  GetSettingsUseCase.swift
//  SettingUseCases
//
//  Created by Tomasz Wojtyniak on 19/02/2026.
//

import LoginUseCases
import SwiftDataManager

public protocol GetSettingsUseCaseProtocol: Sendable {
    func loadAppleMusicStatus() async throws -> Bool
}

public actor GetSettingsUseCase: GetSettingsUseCaseProtocol {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let swiftDataManager: SwiftDataManagerProtocol

    public init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.getLoginUseCase = getLoginUseCase
        self.swiftDataManager = swiftDataManager
    }

    public func loadAppleMusicStatus() async throws -> Bool {
        guard let userId = try await swiftDataManager.getCurrentUserId() else {
            return false
        }
        let profile = try await getLoginUseCase.getUserProfile(userId: userId)
        return profile?.hasAppleMusicSubscription == true
    }
}
