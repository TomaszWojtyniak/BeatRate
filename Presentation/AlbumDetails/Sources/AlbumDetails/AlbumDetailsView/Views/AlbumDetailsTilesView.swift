//
//  AlbumDetailsTilesView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import SwiftUI
import CoreUI
import Models

struct AlbumDetailsTilesView: View {
    
    let album: AlbumModel
    
    var body: some View {
        HStack(spacing: 25) {

            if let rating = album.rating {
                VStack(spacing: 10) {
                    Text("Rating")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        Text(String(format: "%.1f", rating))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .roundedMaterialBackground()
            }
            
            if let releaseDate = album.appleMusicAlbumData.releaseDate {
                VStack(spacing: 10) {
                    Text("Released")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text(releaseDate, format: .dateTime.year())
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .roundedMaterialBackground()
            }
        }
    }
}

#Preview {
    VStack {
        AlbumDetailsTilesView(album: AlbumModel.albumPlaceholder)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.backgroundColor)
}
