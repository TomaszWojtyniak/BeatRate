//
//  HomeSectionView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models

struct HomeSectionView: View {
    
    let name: String
    let albums: [AlbumModel]
    @Binding var selectedAlbum: AlbumModel?
    
    var body: some View {
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
    let previewAlbum = AlbumModel(title: "Album name", artist: "Artist name", coverUrl: nil)
    HomeSectionView(name: "Section name", albums: [previewAlbum], selectedAlbum: .constant(previewAlbum))
}
