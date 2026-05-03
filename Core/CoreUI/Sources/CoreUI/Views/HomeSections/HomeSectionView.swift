//
//  HomeSectionView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models

public struct HomeSectionView: View {

    let name: String
    let albums: [AlbumModel]
    @Binding var selectedAlbum: AlbumModel?

    public init(name: String, albums: [AlbumModel], selectedAlbum: Binding<AlbumModel?>) {
        self.name = name
        self.albums = albums
        self._selectedAlbum = selectedAlbum
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .textStyle(.titleSection)

                Spacer()

                Button {
                    // TODO: navigate to full-list screen for this section
                } label: {
                    Text("See all")
                        .textStyle(.captionEmphasis, color: .accentPrimary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(albums) { album in
                        Button {
                            selectedAlbum = album
                        } label: {
                            SectionAlbumView(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    HomeSectionView(name: "New Releases", albums: [AlbumModel.albumPlaceholder], selectedAlbum: .constant(AlbumModel.albumPlaceholder))
}
