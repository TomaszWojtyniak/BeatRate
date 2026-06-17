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
    let size: CGFloat?

    public init(album: AlbumModel, size: CGFloat? = Size.thumbnailLarge) {
        self.album = album
        self.size = size
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            artwork
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .appShadow(.low)

            VStack(alignment: .leading, spacing: 1) {
                Text(album.appleMusicAlbumData.title)
                    .textStyle(.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: size, alignment: .leading)

                Text(album.appleMusicAlbumData.artist)
                    .textStyle(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: size, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        let cover = AlbumCoverImage(url: album.appleMusicAlbumData.coverUrl)

        if let size {
            cover.frame(width: size, height: size)
        } else {
            cover.aspectRatio(1, contentMode: .fit)
        }
    }
}

#Preview {
    SectionAlbumView(album: AlbumModel.albumPlaceholder)
}
