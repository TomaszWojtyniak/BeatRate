//
//  SearchView.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Models
import AlbumDetails
import ArtistDetails
import CoreUI

@MainActor
public struct SearchView: View {

    /// Which catalog type the search bar targets.
    private enum SearchScope: String, CaseIterable, Identifiable {
        case albums
        case artists

        var id: Self { self }

        var title: String {
            switch self {
            case .albums: "Albums"
            case .artists: "Artists"
            }
        }

        var prompt: String {
            switch self {
            case .albums: "Search albums"
            case .artists: "Search artists"
            }
        }
    }

    @State private var dataModel = SearchDataModel()
    @State private var searchText: String = ""
    @State private var scope: SearchScope = .albums
    @State private var selectedAlbum: AppleMusicAlbumData?
    @State private var selectedArtist: AppleMusicArtistData?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Only offer the album/artist toggle once a search returns
                // something — it's meaningless over recents or an empty state.
                if dataModel.hasResults {
                    Picker("Search scope", selection: $scope) {
                        ForEach(SearchScope.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)
                }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .loading(dataModel.isLoading, message: "Searching...")
            }
            .meshBackground()
            .navigationTitle("Search")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(item: $selectedAlbum) { album in
                AlbumDetailsContainer(albumId: album.id)
            }
            .navigationDestination(item: $selectedArtist) { artist in
                // Bare view in this stack; inject the album screen so the artist
                // page can push album details (AlbumDetails imports ArtistDetails,
                // not the other way around).
                ArtistDetailsView(artistId: artist.id) { album in
                    AnyView(AlbumDetailsView(album: album))
                }
            }
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: scope.prompt
            )
            .onChange(of: searchText) {
                dataModel.searchAlbum(searchTerm: searchText)
            }
            .task {
                await dataModel.loadRecentAlbums()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if searchText.isEmpty {
            // Recents are always albums — we don't track recent artists.
            RecentAlbumsSection(
                albums: dataModel.recentAlbums,
                onAlbumTap: handleAlbumTap,
                onClear: { dataModel.clearRecentAlbums() }
            )
        } else {
            switch scope {
            case .albums: albumResults
            case .artists: artistResults
            }
        }
    }

    @ViewBuilder
    private var albumResults: some View {
        if dataModel.albums.isEmpty {
            if !dataModel.isLoading {
                noResults(for: "albums", icon: "music.note.list")
            }
        } else {
            List(dataModel.albums) { album in
                Button {
                    handleAlbumTap(album)
                } label: {
                    SearchAlbumRow(album: album)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var artistResults: some View {
        if dataModel.artists.isEmpty {
            if !dataModel.isLoading {
                noResults(for: "artists", icon: "person.2")
            }
        } else {
            List(dataModel.artists) { artist in
                Button {
                    handleArtistTap(artist)
                } label: {
                    SearchArtistRow(artist: artist)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func noResults(for what: String, icon: String) -> some View {
        ContentUnavailableView {
            Label("No Results", systemImage: icon)
        } description: {
            Text("No \(what) found for '\(searchText)'")
        }
    }

    // MARK: - Actions

    private func handleAlbumTap(_ album: AppleMusicAlbumData) {
        dataModel.saveRecentAlbum(album)
        selectedAlbum = album
    }

    private func handleArtistTap(_ artist: AppleMusicArtistData) {
        selectedArtist = artist
    }
}

#Preview {
    SearchView()
}
