//
//  AlbumDetailsNavigationStack.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models

public struct AlbumDetailsNavigationStack: View {
    
    let album: AlbumModel
    
    public init(album: AlbumModel) {
        self.album = album
    }
    
    public var body: some View {
        NavigationStack {
            AlbumDetailsView(album: self.album)
        }
    }
}

#Preview {
    AlbumDetailsNavigationStack(album: AlbumModel(title: "Album title", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil))
}
