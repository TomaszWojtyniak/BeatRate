//
//  AlbumDetailsView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Models
import CoreUI

struct AlbumDetailsView: View {
    
    let album: AlbumModel
    @State private var myRating: Double = 0
    
    var body: some View {
        ScrollView {
            VStack {
                AlbumDetailsMainSectionView(album: album)
                
                AlbumDetailsTilesView(album: album)
                    .padding(.top, 20)
                
                RateAlbumView(myRating: $myRating)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 50)
        }
        .background(Color.backgroundColor)
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel(title: "Album title", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: "Pop"))
}
