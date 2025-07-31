//
//  SectionAlbumView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models

struct SectionAlbumView: View {
    
    let album: AlbumModel
    
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: album.coverUrl) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Rectangle()
                    .fill(.gray)
            }
            .frame(width: 150, height: 150)
            .background(.gray)
            .cornerRadius(10)
            
            Text(album.title)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 150, alignment: .leading)
            
            Text(album.artist)
                .font(.system(.caption2, weight: .light))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 150, alignment: .leading)
        }
    }
}

#Preview {
    SectionAlbumView(album: AlbumModel(title: "Album title", artist: "Artist", coverUrl: nil))
}
