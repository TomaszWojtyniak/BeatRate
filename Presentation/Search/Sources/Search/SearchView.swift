//
//  SearchView.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Models
import AlbumDetails
import CoreUI

@MainActor
public struct SearchView: View {

    @State private var dataModel = SearchDataModel()
    @State private var searchText: String = ""
    @State private var selectedAlbum: AppleMusicAlbumData?

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if dataModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.accentPrimary)
                        Text("Searching...")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if dataModel.albums.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "music.note.list")
                    } description: {
                        Text("No albums found for '\(searchText)'")
                    }
                } else if dataModel.albums.isEmpty {
                    RecentAlbumsSection(
                        albums: dataModel.recentAlbums,
                        onAlbumTap: handleAlbumTap,
                        onClear: {
                            dataModel.clearRecentAlbums()
                        }
                    )
                } else {
                    List(dataModel.albums) { album in
                        SearchAlbumRow(album: album)
                            .onTapGesture {
                                handleAlbumTap(album)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .meshBackground()
            .navigationTitle("Search")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(item: $selectedAlbum) { album in
                AlbumDetailsContainer(albumId: album.id)
            }
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search"
            )
            .onChange(of: searchText) {
                dataModel.searchAlbum(searchTerm: searchText)
            }
        }
    }

    private func handleAlbumTap(_ album: AppleMusicAlbumData) {
        dataModel.saveRecentAlbum(album)
        selectedAlbum = album
    }
}

#Preview {
    SearchView()
}
