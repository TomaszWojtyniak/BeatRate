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

    init(album: AlbumModel) {
        self.album = album
        self._dataModel = State(initialValue: AlbumDetailsDataModel(album: album))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                AlbumDetailsCoverView(album: dataModel.album)
                    .padding(.top, Spacing.xxs)

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
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .meshBackground()
        .loading(
            dataModel.isLoading
        )
        .task {
            if let userRating = await dataModel.fetchUserRating() {
                dataModel.myRating = userRating
            }
            dataModel.hasLoadedInitialRating = true
        }
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel.albumPlaceholder)
}
