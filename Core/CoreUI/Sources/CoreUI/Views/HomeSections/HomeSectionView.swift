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
        VStack(alignment: .leading) {
            Text(name)
                .font(.system(.title2, weight: .medium))
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
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
    HomeSectionView(name: "Section name", albums: [AlbumModel.albumPlaceholder], selectedAlbum: .constant(AlbumModel.albumPlaceholder))
}
