//
//  GetAlbumDetailsUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import HomeRepository

public protocol GetAlbumDetailsUseCaseProtocol {
    func saveAlbumRating(albumId: String, rating: Double) async throws
}

public actor GetAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol {
    let homeRepository: HomeRepositoryProtocol
    
    public init(homeRepository: HomeRepositoryProtocol = HomeRepository.shared) {
        self.homeRepository = homeRepository
    }
    
    public func saveAlbumRating(albumId: String, rating: Double) async throws {
        try await self.homeRepository.saveAlbumRating(albumId: albumId, rating: rating)
    }
}
