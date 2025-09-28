//
//  GetHomeUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import MusicRepository
import Models
import HomeRepository
import SwiftDataManager

public protocol GetHomeUseCaseProtocol: Sendable {
    func authorizeMusicKit() async -> Bool
    func getAlbumById(_ id: String) async throws -> AlbumModel
    func fetchHomeSections() async throws -> [HomeSection]
    func isCacheValid() async -> Bool
    func getCachedSections() async throws -> [HomeSection]
}

public actor GetHomeUseCase: GetHomeUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol
    private let homeRepository: HomeRepositoryProtocol
    private let swiftDataManager: SwiftDataManagerProtocol
    
    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
                homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.musicRepository = musicRepository
        self.homeRepository = homeRepository
        self.swiftDataManager = swiftDataManager
    }
    
    public func authorizeMusicKit() async -> Bool {
        return await musicRepository.requestMusicAuthorization()
    }
    
    public func getAlbumById(_ id: String) async throws -> AlbumModel {
        return try await musicRepository.getAlbumById(id)
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        return try await homeRepository.fetchHomeSections()
    }
    
    public func isCacheValid() async -> Bool {
        return await swiftDataManager.isCacheValid()
    }
    
    public func getCachedSections() async throws -> [HomeSection] {
        return try await swiftDataManager.getCachedSections()
    }
}
