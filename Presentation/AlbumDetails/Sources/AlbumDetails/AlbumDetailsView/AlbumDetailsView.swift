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
    @State private var myRating: Double = 0
    
    var body: some View {
        ScrollView {
            VStack {
                AlbumDetailsMainSectionView(album: album)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                
                AlbumDetailsTilesView()
                
                StarRatingView(rating: $myRating)
                    .padding(20)
                
                Spacer(minLength: 50)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel(title: "Album title", artist: "Artist", coverUrl: nil))
}
