//
//  AlbumDetailsView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models
import CoreUI

struct AlbumDetailsView: View {

    let album: AlbumModel
    @State private var dataModel: AlbumDetailsDataModel
    /// Dominant colour pulled from the album artwork, used as the page tint.
    @State private var artworkTint: Color = .clear

    init(album: AlbumModel) {
        self.album = album
        self._dataModel = State(initialValue: AlbumDetailsDataModel(album: album))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AlbumDetailsCoverView(album: dataModel.album)
                    .padding(.top, 6)

                AlbumDetailsMainSectionView(album: dataModel.album)

                AlbumDetailsTilesView(album: dataModel.album)

                RateAlbumView(myRating: $dataModel.myRating) { finalRating in
                    // Only save if initial rating has been loaded
                    guard dataModel.hasLoadedInitialRating else { return }

                    // Use detached task to ensure save completes even if view is dismissed
                    // High priority - direct user action (rating)
                    Task.detached(priority: .userInitiated) { [dataModel] in
                        await dataModel.saveAlbumRating(rating: finalRating)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.backgroundColor)
        .meshBackground(intense: true)
        .loading(
            dataModel.isLoading
        )
        .task {
            if let userRating = await dataModel.fetchUserRating() {
                dataModel.myRating = userRating
            }
            dataModel.hasLoadedInitialRating = true
        }
        .task(id: dataModel.album.appleMusicAlbumData.coverUrl) {
            guard let url = dataModel.album.appleMusicAlbumData.coverUrl else { return }
            artworkTint = await DominantColor.extract(from: url) ?? .clear
        }
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel.albumPlaceholder)
}
