//
//  GetArtistDetailsUseCase.swift
//  ArtistUseCase
//
//  Created by Tomasz Wojtyniak on 15/06/2026.
//

import Foundation
import MusicRepository
import Models
import OSLog

/// Use case for fetching artist details from the Apple Music catalog.
/// Supports two entry points: by artist ID (from search) and by album ID
/// (from album details, where only the artist name is known).
public protocol GetArtistDetailsUseCaseProtocol: Sendable {
    func fetchArtist(byId artistId: String) async throws -> AppleMusicArtistData
    func fetchArtist(forAlbumId albumId: String) async throws -> AppleMusicArtistData
}

public actor GetArtistDetailsUseCase: GetArtistDetailsUseCaseProtocol {
    private let musicRepository: MusicRepositoryProtocol

    public init(musicRepository: MusicRepositoryProtocol = MusicRepository.shared) {
        self.musicRepository = musicRepository
    }

    public func fetchArtist(byId artistId: String) async throws -> AppleMusicArtistData {
        Logger.artistDetails.info("Fetching artist by ID: \(artistId)")
        return try await musicRepository.getArtistData(byId: artistId)
    }

    public func fetchArtist(forAlbumId albumId: String) async throws -> AppleMusicArtistData {
        Logger.artistDetails.info("Fetching artist for album: \(albumId)")
        return try await musicRepository.getArtistData(forAlbumId: albumId)
    }
}
