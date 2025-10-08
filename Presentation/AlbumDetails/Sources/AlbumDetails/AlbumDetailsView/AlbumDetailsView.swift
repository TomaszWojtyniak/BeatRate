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
    @State private var dataModel = AlbumDetailsDataModel()

    var body: some View {
        ScrollView {
            VStack {
                AlbumDetailsMainSectionView(album: album)

                AlbumDetailsTilesView(album: album)
                    .padding(.top, 20)

                RateAlbumView(myRating: $dataModel.myRating)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 50)
        }
        .background(Color.backgroundColor)
        .loading(
            dataModel.isFetchingRating
        )
        .task {
            if let userRating = await dataModel.fetchUserRating(albumId: album.id) {
                dataModel.myRating = userRating
            }
            dataModel.hasLoadedInitialRating = true
        }
        .onChange(of: dataModel.myRating) { oldValue, newValue in
            // Only save if initial rating has been loaded (to prevent saving initial fetch)
            guard dataModel.hasLoadedInitialRating else { return }

            Task {
                await self.dataModel.saveAlbumRating(albumId: self.album.id, rating: newValue)
            }
        }
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel.albumPlaceholder)
}
