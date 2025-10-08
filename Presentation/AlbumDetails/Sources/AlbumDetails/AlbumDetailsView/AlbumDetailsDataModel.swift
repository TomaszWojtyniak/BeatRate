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
    var isLoading = false
    var hasLoadedInitialRating = false

    init(getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol = GetAlbumDetailsUseCase()) {
        self.getAlbumDetailsUseCase = getAlbumDetailsUseCase
    }

    func fetchUserRating(albumId: String) async -> Double? {
        isLoading = true
        defer { isLoading = false }

        do {
            return try await self.getAlbumDetailsUseCase.getUserRating(albumId: albumId)
        } catch let error {
            Logger.albumDetails.error("error fetching user rating: \(error)")
            return nil
        }
    }

    func saveAlbumRating(albumId: String, rating: Double) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await self.getAlbumDetailsUseCase.saveAlbumRating(albumId: albumId, rating: rating)
        } catch let error {
            Logger.albumDetails.error("error saving album: \(error)")
        }
    }
}
