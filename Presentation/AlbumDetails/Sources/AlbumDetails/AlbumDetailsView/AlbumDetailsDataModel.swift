//
//  AlbumDetailsDataModel.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import SwiftUI
import HomeUseCases
import OSLog
import Models
import CoreUI

@MainActor
@Observable
final class AlbumDetailsDataModel {
    private let getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol

    var album: AlbumModel
    var myRating: Double = 0
    var isLoading = false
    var hasLoadedInitialRating = false
    /// Mesh halo tints derived from the album cover. `nil` until extracted;
    /// view falls back to the design-system default halos in the meantime.
    var meshPrimary: Color?
    var meshSecondary: Color?
    private var previousRating: Double = 0

    init(album: AlbumModel, getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol = GetAlbumDetailsUseCase()) {
        self.album = album
        self.getAlbumDetailsUseCase = getAlbumDetailsUseCase
    }

    func fetchUserRating() async -> Double? {
        isLoading = true
        defer { isLoading = false }

        do {
            return try await self.getAlbumDetailsUseCase.getUserRating(albumId: album.id)
        } catch let error {
            Logger.albumDetails.error("error fetching user rating: \(error)")
            return nil
        }
    }

    func saveAlbumRating(rating: Double) async {
        // Store previous rating for rollback in case of error
        previousRating = myRating

        do {
            // Pass album metadata (artist, title) for new albums
            let metadata = (artist: album.appleMusicAlbumData.artist, title: album.appleMusicAlbumData.title)

            try await self.getAlbumDetailsUseCase.saveAlbumRating(
                albumId: album.id,
                rating: rating,
                albumMetadata: metadata
            )
            Logger.albumDetails.info("Successfully saved rating: \(rating)")

            // Refresh album data to get updated avgRating from cache
            await refreshAlbumData()
        } catch let error {
            Logger.albumDetails.error("error saving album: \(error)")
            // Rollback to previous rating on error
            myRating = previousRating
        }
    }

    /// Extracts two dominant colours from the cover artwork and stores them
    /// pre-softened (≈18% alpha) so they can be used directly as mesh halos.
    /// No-op if the album has no cover URL or extraction fails.
    func loadMeshColors() async {
        guard let coverUrl = album.appleMusicAlbumData.coverUrl,
              meshPrimary == nil else { return }

        if let colors = await ArtworkColors.extract(from: coverUrl) {
            meshPrimary = colors.primary.opacity(0.65)
            meshSecondary = colors.secondary.opacity(0.55)
        }
    }

    func refreshAlbumData() async {
        do {
            if let updatedAlbum = try await getAlbumDetailsUseCase.getUpdatedAlbum(albumId: album.id) {
                self.album = updatedAlbum
                Logger.albumDetails.info("Refreshed album data with updated avgRating")
            }
        } catch {
            Logger.albumDetails.error("Failed to refresh album data: \(error)")
        }
    }
}
