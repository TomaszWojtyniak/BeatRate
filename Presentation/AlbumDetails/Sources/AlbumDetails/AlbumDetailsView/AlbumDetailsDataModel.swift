//
//  AlbumDetailsDataModel.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import HomeUseCases
import OSLog

@MainActor
@Observable
final class AlbumDetailsDataModel {
    private let getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol

    var myRating: Double = 0
    var isFetchingRating = false
    var hasLoadedInitialRating = false
    private var previousRating: Double = 0

    init(getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol = GetAlbumDetailsUseCase()) {
        self.getAlbumDetailsUseCase = getAlbumDetailsUseCase
    }

    func fetchUserRating(albumId: String) async -> Double? {
        isFetchingRating = true
        defer { isFetchingRating = false }

        do {
            return try await self.getAlbumDetailsUseCase.getUserRating(albumId: albumId)
        } catch let error {
            Logger.albumDetails.error("error fetching user rating: \(error)")
            return nil
        }
    }

    func saveAlbumRating(albumId: String, rating: Double) async {
        // Store previous rating for rollback in case of error
        previousRating = myRating

        do {
            try await self.getAlbumDetailsUseCase.saveAlbumRating(albumId: albumId, rating: rating)
            Logger.albumDetails.info("Successfully saved rating: \(rating)")
        } catch let error {
            Logger.albumDetails.error("error saving album: \(error)")
            // Rollback to previous rating on error
            myRating = previousRating
        }
    }
}
