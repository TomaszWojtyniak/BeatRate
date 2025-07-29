//
//  GetHomeUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import MusicRepository
import Models

public protocol GetHomeUseCaseProtocol: Sendable {
    func authorizeMusicKit() async -> Bool
    func getAlbumById(_ id: String) async throws -> AlbumModel
}

public actor GetHomeUseCase: GetHomeUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol
    
    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared) {
        self.musicRepository = musicRepository
    }
    
    public func authorizeMusicKit() async -> Bool {
        return await musicRepository.requestMusicAuthorization()
    }
    
    public func getAlbumById(_ id: String) async throws -> AlbumModel {
        return try await musicRepository.getAlbumById(id)
    }
}
