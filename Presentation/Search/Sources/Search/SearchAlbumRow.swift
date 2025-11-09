//
//  SearchAlbumRow.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 25/10/2025.
//

import SwiftUI
import Models

struct SearchAlbumRow: View {
    let album: AppleMusicAlbumData

    var body: some View {
        HStack(spacing: 12) {
            // Album Artwork
            if let coverUrl = album.coverUrl {
                AsyncImage(url: coverUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }

            // Album Info
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(album.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let genre = album.genre {
                    Text(genre)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    SearchAlbumRow(album: .albumPlaceholder)
}
