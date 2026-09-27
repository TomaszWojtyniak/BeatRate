//
//  ArtistDetailsView.swift
//  ArtistDetails
//
//  Created by Tomasz Wojtyniak on 17/06/2026.
//

import SwiftUI
import Models
import CoreUI
import Analytics

public struct ArtistDetailsView: View {

    @State private var dataModel: ArtistDetailsDataModel
    @State private var selectedAlbum: AlbumModel?
    @State private var gridSelectedAlbum: AlbumModel?
    @State private var selectedSection: HomeSection?

    private let albumDestination: (AlbumModel) -> AnyView

    public init(
        albumId: String,
        albumDestination: @escaping (AlbumModel) -> AnyView = { _ in AnyView(EmptyView()) }
    ) {
        self._dataModel = State(initialValue: ArtistDetailsDataModel(source: .albumId(albumId)))
        self.albumDestination = albumDestination
    }

    public init(
        artistId: String,
        albumDestination: @escaping (AlbumModel) -> AnyView = { _ in AnyView(EmptyView()) }
    ) {
        self._dataModel = State(initialValue: ArtistDetailsDataModel(source: .artistId(artistId)))
        self.albumDestination = albumDestination
    }

    public var body: some View {
        Group {
            if let artist = dataModel.artist {
                content(artist: artist)
            } else if dataModel.loadFailed {
                failedView
            }
        }
        .loading(
            dataModel.isLoading,
            message: "Loading artist"
        )
        .onAppear {
            dataModel.loadIfNeeded()
        }
        .onAppear { dataModel.track(.screenView(.artistDetails)) }
    }
    
    private func content(artist: AppleMusicArtistData) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: Spacing.md) {
                LazyVStack(spacing: Spacing.md) {
                    ArtistHeaderView(artist: artist)
                        .padding(.horizontal, Spacing.md)

                    ForEach(dataModel.sections) { section in
                        HomeSectionView(
                            name: section.sectionName,
                            albums: section.albums,
                            selectedAlbum: $selectedAlbum
                        ) {
                            selectedSection = section
                        }
                        .padding(Spacing.lg)
                        .roundedMaterialBackground()
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.bottom, Spacing.lg)
            }
        }
        .meshBackground()
        .navigationDestination(item: $selectedSection) { section in
            SectionAlbumsGridView(name: section.sectionName, albums: section.albums, selectedAlbum: $gridSelectedAlbum)
                .onAppear { dataModel.track(.screenView(.sectionGrid, ["section": section.sectionName, "source": AnalyticsScreen.artistDetails.rawValue])) }
        }
        .navigationDestination(item: $selectedAlbum) { album in
            albumDestination(album)
        }
        .navigationDestination(item: $gridSelectedAlbum) { album in
            albumDestination(album)
        }
        .onChange(of: selectedAlbum) { _, album in
            guard let album else { return }
            let section = dataModel.sections.first { $0.albums.contains { $0.id == album.id } }
            dataModel.track(.albumTap(source: .artist, albumId: album.id, section: section?.sectionName))
        }
        .onChange(of: gridSelectedAlbum) { _, album in
            guard let album else { return }
            dataModel.track(.albumTap(source: .sectionGrid, albumId: album.id, section: selectedSection?.sectionName))
        }
    }

    private var failedView: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Failed to load artist.")
        } actions: {
            Button("Try Again") {
                dataModel.track(.retryTap(screen: .artistDetails))
                dataModel.loadIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ArtistDetailsView(albumId: "123")
}
