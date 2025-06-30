//
//  AlbumDetailsNavigationStack.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models

public struct AlbumDetailsNavigationStack: View {
    
    let album: Album
    
    public init(album: Album) {
        self.album = album
    }
    
    public var body: some View {
        NavigationStack {
            AlbumDetailsView(album: self.album)
        }
    }
}

#Preview {
    AlbumDetailsNavigationStack(album: Album(title: "Album title", artist: "Artist", cover: ""))
}
