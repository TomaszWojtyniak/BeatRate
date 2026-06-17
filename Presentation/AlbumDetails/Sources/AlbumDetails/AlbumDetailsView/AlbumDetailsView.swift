//
//  AlbumDetailsView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models
import CoreUI
import ArtistDetails

public struct AlbumDetailsView: View {

    let album: AlbumModel
    @State private var dataModel: AlbumDetailsDataModel
    @State private var selectedAlbumId: String?

    public init(album: AlbumModel) {
        self.album = album
        self._dataModel = State(initialValue: AlbumDetailsDataModel(album: album))
    }

    public var body: some View {
        ZStack {
            MeshBackground(
                primary: dataModel.meshPrimary ?? .accentPrimarySoft,
                secondary: dataModel.meshSecondary ?? .accentSecondarySoft
            )
            .animation(AppAnimation.smooth, value: dataModel.meshPrimary)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    AlbumDetailsCoverView(album: dataModel.album)
                        .padding(.top, Spacing.xxs)

                    AlbumDetailsMainSectionView(album: dataModel.album) {
                        selectedAlbumId = dataModel.album.appleMusicAlbumData.id
                    }

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

                    if let tracks = dataModel.album.appleMusicAlbumData.tracks, !tracks.isEmpty {
                        AlbumTracklistView(tracks: tracks)
                    }

                    AlbumDetailsFooterView(
                        album: dataModel.album.appleMusicAlbumData,
                        playUrl: dataModel.playUrl,
                        playLabel: dataModel.playLabel,
                        playPlayer: dataModel.playPlayer
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .loading(
            dataModel.isLoading
        )
        .navigationDestination(item: $selectedAlbumId) { albumId in
            // Bare view in the existing stack. Inject the album destination so
            // ArtistDetails can push album details back without importing AlbumDetails.
            ArtistDetailsView(albumId: albumId) { album in
                AnyView(AlbumDetailsView(album: album))
            }
        }
        .task {
            if let userRating = await dataModel.fetchUserRating() {
                dataModel.myRating = userRating
            }
            dataModel.hasLoadedInitialRating = true
        }
        .task {
            await dataModel.loadMeshColors()
        }
        .task {
            await dataModel.loadTracksIfNeeded()
        }
        .task {
            await dataModel.resolvePlayUrl()
        }
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel.albumPlaceholder)
}
