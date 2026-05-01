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
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: album.appleMusicAlbumData.coverUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.albumPlaceholderColor)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 138, height: 138)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .appShadow(.low)

            VStack(alignment: .leading, spacing: 1) {
                Text(album.appleMusicAlbumData.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 138, alignment: .leading)

                Text(album.appleMusicAlbumData.artist)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 138, alignment: .leading)
            }
        }
    }
}

#Preview {
    SectionAlbumView(album: AlbumModel.albumPlaceholder)
}
