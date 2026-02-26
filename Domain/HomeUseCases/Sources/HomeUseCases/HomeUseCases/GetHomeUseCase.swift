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

public protocol GetHomeUseCaseProtocol: Sendable {
    func authorizeMusicKit() async -> MusicAuthorizationInfo
    func fetchHomeSections() async throws -> [HomeSection]
}

public actor GetHomeUseCase: GetHomeUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol
    private let homeRepository: HomeRepositoryProtocol
    
    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
                homeRepository: HomeRepositoryProtocol = HomeRepository.shared) {
        self.musicRepository = musicRepository
        self.homeRepository = homeRepository
    }
    
    public func authorizeMusicKit() async -> MusicAuthorizationInfo {
        return await musicRepository.requestMusicAuthorization()
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        return try await homeRepository.fetchHomeSections()
    }
    
}
