//
//  AlbumDetailsView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models

struct AlbumDetailsView: View {
    
    let album: Album
    
    var body: some View {
        Text("Album: \(album.id)")
    }
}

#Preview {
    AlbumDetailsView(album: Album(title: "Album title", artist: "Artist", cover: ""))
}
