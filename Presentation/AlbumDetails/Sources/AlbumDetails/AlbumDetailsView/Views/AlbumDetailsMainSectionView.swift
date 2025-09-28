//
//  AlbumDetailsMainSectionView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import SwiftUI
import Models

struct AlbumDetailsMainSectionView: View {
    
    let album: AlbumModel
    
    var body: some View {
        VStack {
            AsyncImage(url: album.appleMusicAlbumData.coverUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 300, height: 300)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 12) {
                Text(album.appleMusicAlbumData.title)
                    .font(.system(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal)
                
                Text(album.appleMusicAlbumData.artist)
                    .font(.system(.title2, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    AlbumDetailsView(album: AlbumModel.albumPlaceholder)
}
