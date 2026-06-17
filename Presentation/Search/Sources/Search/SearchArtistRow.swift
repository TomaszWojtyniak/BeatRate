//
//  SearchArtistRow.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 17/06/2026.
//

import SwiftUI
import Models
import CoreUI

/// Search result row for an artist. Mirrors `SearchAlbumRow`, but the artwork
/// is a circular artist photo rather than a square album cover.
struct SearchArtistRow: View {
    let artist: AppleMusicArtistData

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Artist photo — circular, same loader/size as the album row.
            AlbumCoverImage(url: artist.imageUrl, placeholderIconStyle: .iconPlaceholder)
                .frame(width: Size.thumbnailSmall, height: Size.thumbnailSmall)
                .clipShape(Circle())
                .appShadow(.low)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(artist.name)
                    .textStyle(.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !artist.genres.isEmpty {
                    Text(artist.genres.joined(separator: ", "))
                        .textStyle(.caption)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .textStyle(.iconRowAccessory, foreground: .tertiary)
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
    }
}

#Preview {
    SearchArtistRow(artist: .artistPlaceholder)
        .padding()
}
