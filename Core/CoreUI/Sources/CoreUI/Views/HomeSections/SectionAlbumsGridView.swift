//
//  SectionAlbumsGridView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 11/06/2026.
//

import SwiftUI
import Models

/// Full-screen, vertically scrolling grid showing every album of a section.
/// Pushed from a section's "See all" button.
public struct SectionAlbumsGridView: View {

    private static let columnCount = 2

    let name: String
    let albums: [AlbumModel]
    @Binding var selectedAlbum: AlbumModel?

    public init(name: String, albums: [AlbumModel], selectedAlbum: Binding<AlbumModel?>) {
        self.name = name
        self.albums = albums
        self._selectedAlbum = selectedAlbum
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: Self.columnCount),
                spacing: Spacing.lg
            ) {
                ForEach(albums) { album in
                    Button {
                        selectedAlbum = album
                    } label: {
                        SectionAlbumView(album: album, size: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .meshBackground()
        .navigationTitle(name)
    }
}

#Preview {
    NavigationStack {
        SectionAlbumsGridView(
            name: "New Releases",
            albums: [AlbumModel.albumPlaceholder],
            selectedAlbum: .constant(nil)
        )
    }
}
