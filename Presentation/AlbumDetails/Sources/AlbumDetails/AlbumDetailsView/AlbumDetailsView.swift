//
//  AlbumDetailsView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models

struct AlbumDetailsView: View {
    
    let album: AlbumModel
    
    var body: some View {
        Text("Album: \(album.id)")
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel(title: "Album title", artist: "Artist", coverUrl: URL(string: "")))
}
