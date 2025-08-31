//
//  SectionAlbumView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models
import CoreUI

struct SectionAlbumView: View {
    
    let album: AlbumModel
    
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: album.coverUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.albumPlaceholderColor)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 150, height: 150)
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
    SectionAlbumView(album: AlbumModel(title: "Album title", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil))
}
