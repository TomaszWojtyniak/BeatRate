//
//  AlbumDetailsMainSectionView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import SwiftUI
import Models
import CoreUI

/// Centered album cover — a 280×280 rounded square with depth shadow.
struct AlbumDetailsCoverView: View {
    let album: AlbumModel

    var body: some View {
        AsyncImage(url: album.appleMusicAlbumData.coverUrl) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.albumPlaceholderColor)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .appShadow(.high)
    }
}

struct AlbumDetailsMainSectionView: View {

    let album: AlbumModel

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(album.appleMusicAlbumData.title)
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Color.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Text(album.appleMusicAlbumData.artist)
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal)

            // Genre chip (if available)
            if let genre = album.appleMusicAlbumData.genre {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 11, weight: .semibold))
                    Text(genre)
                        .font(.system(.footnote, weight: .semibold))
                }
                .foregroundStyle(Color.accentSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.accentSecondaryTint)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.accentSecondary.opacity(0.25), lineWidth: 0.5)
                )
            }
        }
    }
}

#Preview {
    AlbumDetailsMainSectionView(album: AlbumModel.albumPlaceholder)
        .padding()
        .background(Color.backgroundColor)
}
