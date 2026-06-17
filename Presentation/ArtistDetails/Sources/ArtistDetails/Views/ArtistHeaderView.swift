//
//  ArtistHeaderView.swift
//  ArtistDetails
//
//  Created by Tomasz Wojtyniak on 15/06/2026.
//

import SwiftUI
import Models
import CoreUI

/// Artist name and photo.
struct ArtistHeaderView: View {

    let artist: AppleMusicArtistData

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text(artist.name)
                .textStyle(.displayLarge)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            AlbumCoverImage(url: artist.imageUrl, contentMode: .fill, placeholderIconStyle: .iconPlaceholder)
                .frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)
                .clipShape(Circle())
                .appShadow(.high)
        }
        .padding(.horizontal, Spacing.lg)
    }
}

#Preview {
    ArtistHeaderView(artist: .artistPlaceholder)
        .padding()
        .background(Color.backgroundColor)
}
