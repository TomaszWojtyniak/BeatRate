//
//  HomeSectionView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models

public struct HomeSectionView: View {

    private static let seeAllThreshold = 10

    let name: String
    let albums: [AlbumModel]
    @Binding var selectedAlbum: AlbumModel?
    let onSeeAll: (() -> Void)?

    public init(name: String, albums: [AlbumModel], selectedAlbum: Binding<AlbumModel?>, onSeeAll: (() -> Void)? = nil) {
        self.name = name
        self.albums = albums
        self._selectedAlbum = selectedAlbum
        self.onSeeAll = onSeeAll
    }

    private var visibleAlbums: [AlbumModel] {
        onSeeAll != nil ? Array(albums.prefix(Self.seeAllThreshold)) : albums
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .textStyle(.titleSection)

                Spacer()

                if albums.count > Self.seeAllThreshold, let onSeeAll {
                    Button(action: onSeeAll) {
                        Text("See all", bundle: .module)
                            .textStyle(.captionEmphasis, color: .accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(visibleAlbums) { album in
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
