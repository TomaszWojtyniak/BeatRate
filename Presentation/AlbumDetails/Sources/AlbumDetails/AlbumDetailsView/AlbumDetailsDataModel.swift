//
//  AlbumDetailsDataModel.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import HomeUseCases
import OSLog
import Models

@MainActor
@Observable
final class AlbumDetailsDataModel {
    private let getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol

    var album: AlbumModel
    var myRating: Double = 0
    var isLoading = false
    var hasLoadedInitialRating = false
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
            try await self.getAlbumDetailsUseCase.saveAlbumRating(albumId: album.id, rating: rating)
            Logger.albumDetails.info("Successfully saved rating: \(rating)")

            // Refresh album data to get updated avgRating
            await refreshAlbumData()
        } catch let error {
            Logger.albumDetails.error("error saving album: \(error)")
            // Rollback to previous rating on error
            myRating = previousRating
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
