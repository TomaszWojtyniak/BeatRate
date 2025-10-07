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
    
    init(getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol = GetAlbumDetailsUseCase()) {
        self.getAlbumDetailsUseCase = getAlbumDetailsUseCase
    }
    
    func saveAlbumRating(albumId: String, rating: Double) async {
        do {
            try await self.getAlbumDetailsUseCase.saveAlbumRating(albumId: albumId, rating: rating)
        } catch let error {
            Logger.albumDetails.error("error saving album: \(error)")
        }
    }
}
