//
//  SearchView.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Models

@MainActor
public struct SearchView: View {

    @State private var dataModel = SearchDataModel()
    @State private var searchText: String = ""
    @State var selectedAlbum: AppleMusicAlbumData?

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if dataModel.isLoading {
                    ProgressView("Searching...")
                } else if dataModel.albums.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "music.note.list")
                    } description: {
                        Text("No albums found for '\(searchText)'")
                    }
                } else if dataModel.albums.isEmpty {
                    ContentUnavailableView("Search music", systemImage: "magnifyingglass")
                } else {
                    List(dataModel.albums, id: \.title) { album in
                        SearchAlbumRow(album: album)
                            .onTapGesture {
                                self.selectedAlbum = album
                            }
                    }
                    .listStyle(.automatic)
                }
            }
            .navigationTitle("Search")
        }
        .navigationDestination(item: $selectedAlbum) { album in
            
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: "Search"
        )
        .onChange(of: searchText) {
            Task {
                try await dataModel.searchAlbum(searchTerm: searchText)
            }
        }
    }
}

#Preview {
    SearchView()
}
