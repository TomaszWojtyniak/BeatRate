//
//  GetAlbumDetailsUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import HomeRepository
import Models

public protocol GetAlbumDetailsUseCaseProtocol {
    func getUserRating(albumId: String) async throws -> Double?
    func saveAlbumRating(albumId: String, rating: Double) async throws
    func getUpdatedAlbum(albumId: String) async throws -> AlbumModel?
}

public actor GetAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol {
    let homeRepository: HomeRepositoryProtocol

    public init(homeRepository: HomeRepositoryProtocol = HomeRepository.shared) {
        self.homeRepository = homeRepository
    }

    public func getUserRating(albumId: String) async throws -> Double? {
        return try await self.homeRepository.getUserRating(albumId: albumId)
    }

    public func saveAlbumRating(albumId: String, rating: Double) async throws {
        try await self.homeRepository.saveAlbumRating(albumId: albumId, rating: rating)
    }

    public func getUpdatedAlbum(albumId: String) async throws -> AlbumModel? {
        return try await self.homeRepository.getCachedAlbum(albumId: albumId)
    }
}
