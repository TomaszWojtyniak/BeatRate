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

    let _album: AlbumModel
    @State private var dataModel: AlbumDetailsDataModel

    init(album: AlbumModel) {
        self._album = album
        self._dataModel = State(initialValue: AlbumDetailsDataModel(album: album))
    }

    var body: some View {
        ScrollView {
            VStack {
                AlbumDetailsMainSectionView(album: dataModel.album)

                AlbumDetailsTilesView(album: dataModel.album)
                    .padding(.top, 20)

                RateAlbumView(myRating: $dataModel.myRating) { finalRating in
                    // Only save if initial rating has been loaded
                    guard dataModel.hasLoadedInitialRating else { return }

                    Task {
                        await self.dataModel.saveAlbumRating(rating: finalRating)
                    }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 50)
        }
        .background(Color.backgroundColor)
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
