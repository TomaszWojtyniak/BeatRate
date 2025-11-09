//
//  GetAlbumByIdUseCase.swift
//  HomeUseCases
//
//  Created by Claude on 25/10/2025.
//

import Foundation
import HomeRepository
import MusicRepository
import Models
import OSLog

/// Use case for fetching album data by ID
/// Checks cache first (only albums in home sections are cached)
/// Falls back to MusicKit if not in cache
public protocol GetAlbumByIdUseCaseProtocol: Sendable {
    func execute(albumId: String) async throws -> AlbumModel
}

public actor GetAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol {
    private let homeRepository: HomeRepositoryProtocol
    private let musicRepository: MusicRepositoryProtocol

    public init(
        homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
        musicRepository: MusicRepositoryProtocol = MusicRepository.shared
    ) {
        self.homeRepository = homeRepository
        self.musicRepository = musicRepository
    }

    public func execute(albumId: String) async throws -> AlbumModel {
        // First, try to get from cache (only albums in home sections)
        if let cachedAlbum = try await homeRepository.getCachedAlbum(albumId: albumId) {
            Logger.albumDetails.info("Album \(albumId) found in cache")
            return cachedAlbum
        }

        // Not in cache, fetch from MusicKit AND Firebase in parallel
        Logger.albumDetails.info("Album \(albumId) not in cache, fetching from MusicKit and Firebase")

        async let appleMusicDataTask = musicRepository.getAlbumDataById(albumId)
        async let firebaseDataTask = homeRepository.getFirebaseAlbumData(albumId: albumId)

        let appleMusicData = try await appleMusicDataTask
        let firebaseData = try? await firebaseDataTask  // Firebase data is optional (may not exist yet)

        // Create AlbumModel with both Apple Music and Firebase data
        let albumModel = await AlbumModel(
            id: albumId,
            appleMusicAlbumData: appleMusicData,
            firebaseAlbumData: firebaseData
        )

        Logger.albumDetails.info("Fetched album \(albumId) - Firebase data exists: \(firebaseData != nil)")
        return albumModel
    }
}
