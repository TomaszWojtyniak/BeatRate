//
//  GetAppUseCase.swift
//  AppUseCases
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import SwiftDataManager
import SwiftData
import Models

public protocol GetAppUseCaseProtocol: Sendable {
    func getCurrentUser() async throws -> User?
    func isUserLoggedIn() async -> Bool
    func observeLoginState() -> AsyncStream<Bool>
}

public actor GetAppUseCase: GetAppUseCaseProtocol {
    let swiftDataManager: SwiftDataManagerProtocol

    public init(swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.swiftDataManager = swiftDataManager
    }

    @MainActor
    public func getCurrentUser() async throws -> User? {
        try await self.swiftDataManager.getCurrentUser()
    }

    @MainActor
    public func isUserLoggedIn() async -> Bool {
        await self.swiftDataManager.isUserLoggedIn()
    }

    @MainActor
    public func observeLoginState() -> AsyncStream<Bool> {
        self.swiftDataManager.observeLoginState()
    }
}
