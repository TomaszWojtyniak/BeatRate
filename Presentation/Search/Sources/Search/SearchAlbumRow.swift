//
//  SearchAlbumRow.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 25/10/2025.
//

import SwiftUI
import Models
import CoreUI

struct SearchAlbumRow: View {
    let album: AppleMusicAlbumData

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Album Artwork
            Group {
                if let coverUrl = album.coverUrl {
                    AsyncImage(url: coverUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.albumPlaceholderColor)
                    }
                } else {
                    Rectangle()
                        .fill(Color.albumPlaceholderColor)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: Size.thumbnailSmall, height: Size.thumbnailSmall)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .appShadow(.low)

            // Album Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(album.title)
                    .textStyle(.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(album.artist)
                    .textStyle(.caption)
                    .lineLimit(1)

                if let genre = album.genre {
                    Text(genre)
                        .textStyle(.label)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

#Preview {
    SearchAlbumRow(album: .albumPlaceholder)
        .padding()
}
