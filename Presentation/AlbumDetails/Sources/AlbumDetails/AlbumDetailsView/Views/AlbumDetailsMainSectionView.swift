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
        AlbumCoverImage(url: album.appleMusicAlbumData.coverUrl, contentMode: .fit, placeholderIconStyle: .iconHero)
            .frame(width: Size.coverHero, height: Size.coverHero)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .appShadow(.high)
    }
}

struct AlbumDetailsMainSectionView: View {

    let album: AlbumModel

    var body: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.xxs) {
                Text(album.appleMusicAlbumData.title)
                    .textStyle(.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Text(album.appleMusicAlbumData.artist)
                    .textStyle(.secondaryDetail, color: .secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal)

            // Genre chip (if available)
            if let genre = album.appleMusicAlbumData.genre {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "music.note.list")
                        .textStyle(.iconChip, color: .accentSecondary)
                    Text(genre)
                        .textStyle(.captionEmphasis, color: .accentSecondary)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(
                    Capsule()
                        .fill(Color.accentSecondaryTint)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.accentSecondary.opacity(0.25), lineWidth: Stroke.hairline)
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
