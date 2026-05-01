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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primary)
                    .tracking(-0.4)

                Spacer()

                Text("See all")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
                    .onTapGesture {
                        //TODO: Add Full screen list
                    }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(albums) { album in
                        SectionAlbumView(album: album)
                            .onTapGesture {
                                self.selectedAlbum = album
                            }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeSectionView(name: "New Releases", albums: [AlbumModel.albumPlaceholder], selectedAlbum: .constant(AlbumModel.albumPlaceholder))
}
