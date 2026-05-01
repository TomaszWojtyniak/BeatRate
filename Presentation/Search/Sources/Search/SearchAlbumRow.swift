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
        HStack(spacing: 14) {
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
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .appShadow(.low)

            // Album Info
            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(album.artist)
                    .font(.system(.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let genre = album.genre {
                    Text(genre)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
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
