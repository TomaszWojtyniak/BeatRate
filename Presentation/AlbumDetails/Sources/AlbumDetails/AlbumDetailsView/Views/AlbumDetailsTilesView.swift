//
//  AlbumDetailsTilesView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import SwiftUI
import CoreUI
import Models

struct AlbumDetailsTilesView: View {

    let album: AlbumModel

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StatTile(label: String(localized: .albumTileRating),
                     systemImage: "star.fill",
                     iconColor: Color.accentPrimary,
                     tint: Color.accentPrimaryTint) {
                if let ratingCount = album.firebaseAlbumData?.ratingCount, ratingCount > 0,
                   let rating = album.firebaseAlbumData?.avgRating {
                    Text(rating, format: .number.precision(.fractionLength(1)))
                        .textStyle(.statValue)
                } else {
                    Text(verbatim: "-")
                        .textStyle(.statValue, color: .secondaryText)
                }
            }

            if let releaseDate = album.appleMusicAlbumData.releaseDate {
                StatTile(label: String(localized: .albumTileReleased),
                         systemImage: "calendar",
                         iconColor: Color.accentSecondary,
                         tint: Color.accentSecondaryTint) {
                    Text(releaseDate, format: .dateTime.year())
                        .textStyle(.statValue)
                }
            }
        }
    }
}

#Preview {
    VStack {
        AlbumDetailsTilesView(album: AlbumModel.albumPlaceholder)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.backgroundColor)
}
