//
//  GetSplashUseCase.swift
//  SplashUseCases
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import MusicRepository
import HomeRepository
import SwiftDataManager
import Models

public protocol GetSplashUseCaseProtocol: Sendable {
    func getCachedSections() async throws -> [HomeSection]
    func fetchHomeSections() async throws -> [HomeSection]
    func authorizeMusicKit() async -> Bool
    func cacheSections(_ sections: [HomeSection]) async throws
    func isCacheValid() async -> Bool
}

public actor GetSplashUseCase: GetSplashUseCaseProtocol {
    private let musicRepository: MusicRepository
    private let homeRepository: HomeRepository
    private let swiftDataManager: SwiftDataManager
    
    public init(musicRepository: MusicRepository = .shared,
         homeRepository: HomeRepository = .shared,
         swiftDataManager: SwiftDataManager = .shared) {
        self.musicRepository = musicRepository
        self.homeRepository = homeRepository
        self.swiftDataManager = swiftDataManager
    }
    
    public func getCachedSections() async throws -> [HomeSection] {
        return try await swiftDataManager.getCachedSections()
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        return try await homeRepository.fetchHomeSections()
    }
    
    public func authorizeMusicKit() async -> Bool {
        return await musicRepository.requestMusicAuthorization()
    }
    
    public func cacheSections(_ sections: [HomeSection]) async throws {
        try await swiftDataManager.cacheSections(sections)
    }
    
    public func isCacheValid() async -> Bool {
        return await swiftDataManager.isCacheValid()
    }
}
