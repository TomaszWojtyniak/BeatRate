//
//  SectionAlbumView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Models

public struct SectionAlbumView: View {

    let album: AlbumModel

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AsyncImage(url: album.appleMusicAlbumData.coverUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.albumPlaceholderColor)
                    .overlay {
                        Image(systemName: "music.note")
                            .textStyle(.iconPlaceholder, color: .secondaryText)
                    }
            }
            .frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .appShadow(.low)

            VStack(alignment: .leading, spacing: 1) {
                Text(album.appleMusicAlbumData.title)
                    .textStyle(.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: Size.thumbnailLarge, alignment: .leading)

                Text(album.appleMusicAlbumData.artist)
                    .textStyle(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: Size.thumbnailLarge, alignment: .leading)
            }
        }
    }
}

#Preview {
    SectionAlbumView(album: AlbumModel.albumPlaceholder)
}
