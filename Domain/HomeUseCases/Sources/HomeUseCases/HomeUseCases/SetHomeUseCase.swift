//
//  SetHomeUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import MusicKitService
import SwiftDataManager

public protocol SetHomeUseCaseProtocol: Sendable {
    func clearCache() async throws
    
}

public actor SetHomeUseCase: SetHomeUseCaseProtocol {
    private let musicKitService: MusicKitServiceProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    
    public init(musicKitService: MusicKitServiceProtocol = MusicKitService.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.musicKitService = musicKitService
        self.swiftDataManager = swiftDataManager
    }
    
    public func clearCache() async throws {
        try await self.swiftDataManager.clearCache()
    }
}
