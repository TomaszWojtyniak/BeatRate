//
//  SectionAlbumView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models

struct SectionAlbumView: View {
    
    let album: Album
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(album.cover)
                .resizable()
                .frame(width: 150, height: 150)
                .aspectRatio(contentMode: .fit)
                .background(.red)
                .cornerRadius(10)
            
            Text(album.title)
                .font(.caption)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.system(.caption2, weight: .light))
                .lineLimit(1)
        }
    }
}

#Preview {
    SectionAlbumView(album: Album(title: "Album title", artist: "Artist", cover: ""))
}
