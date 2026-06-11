//
//  GetAlbumDetailsUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import HomeRepository
import MusicRepository
import Models

public protocol GetAlbumDetailsUseCaseProtocol: Sendable {
    func getUserRating(albumId: String) async throws -> Double?
    func saveAlbumRating(albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws
    func getUpdatedAlbum(albumId: String) async throws -> AlbumModel?
    func fetchFullAlbum(albumId: String) async throws -> AlbumModel
    func searchSpotifyAlbumId(name: String, artist: String) async -> String?
}

public actor GetAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol {
    let homeRepository: HomeRepositoryProtocol
    let musicRepository: MusicRepositoryProtocol

    public init(homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
                musicRepository: MusicRepositoryProtocol = MusicRepository.shared) {
        self.homeRepository = homeRepository
        self.musicRepository = musicRepository
    }

    public func getUserRating(albumId: String) async throws -> Double? {
        return try await self.homeRepository.getUserRating(albumId: albumId)
    }

    public func saveAlbumRating(albumId: String, rating: Double, albumMetadata: (artist: String, title: String)? = nil) async throws {
        try await self.homeRepository.saveAlbumRating(albumId: albumId, rating: rating, albumMetadata: albumMetadata)
    }

    public func getUpdatedAlbum(albumId: String) async throws -> AlbumModel? {
        return try await self.homeRepository.getCachedAlbum(albumId: albumId)
    }

    public func fetchFullAlbum(albumId: String) async throws -> AlbumModel {
        return try await self.homeRepository.fetchAndCacheAlbum(albumId: albumId)
    }

    public func searchSpotifyAlbumId(name: String, artist: String) async -> String? {
        await musicRepository.searchSpotifyAlbumId(name: name, artist: artist)
    }
}
