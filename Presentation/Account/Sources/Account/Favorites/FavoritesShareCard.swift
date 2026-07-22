//
//  FavoritesShareCard.swift
//  Account
//
//  Created by Claude on 22/07/2026.
//

import SwiftUI
import CoreUI

/// A single resolved favorite for the share card: artwork is pre-loaded into a
/// `UIImage` because `ImageRenderer` snapshots synchronously and won't wait for
/// async artwork loads.
struct ResolvedFavorite: Identifiable {
    let id: String
    let cover: UIImage?
    let title: String
    let artist: String
}

/// The exportable "My favorites" card. Built as a fixed-size view so
/// `ImageRenderer` produces a device-independent PNG. Its outer dimensions are
/// a deterministic export canvas — named local constants rather than layout
/// tokens — while all inner chrome uses the design system.
struct FavoritesShareCard: View {

    // Fixed export canvas (9:16). Not a responsive app view.
    static let canvasWidth: CGFloat = 360
    static let canvasHeight: CGFloat = 640
    private let wordmarkHeight: CGFloat = 40

    let name: String
    let albums: [ResolvedFavorite]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Spacer()

                WordmarkView()
                    .frame(height: wordmarkHeight)

                Spacer()
            }
            
            titleBlock
            
            grid
            
            Spacer(minLength: 0)
            
            footer
        }
        .padding(Spacing.lg)
        .frame(width: Self.canvasWidth, height: Self.canvasHeight)
        .background(Color.backgroundGradient)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Favorite Albums")
                .textStyle(.label, color: .accentPrimary)
                .textCase(.uppercase)

            Text("My favorites")
                .textStyle(.title, color: .primaryTextOnDark)

            if !name.isEmpty {
                Text(name)
                    .textStyle(.body, color: .secondaryTextOnDark)
            }
        }
    }

    // MARK: - Covers

    private var grid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.sm),
                GridItem(.flexible(), spacing: Spacing.sm)
            ],
            spacing: Spacing.sm
        ) {
            ForEach(albums) { favorite in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    cover(favorite.cover)
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        .appShadow(.low)

                    Text(favorite.title)
                        .textStyle(.caption, color: .primaryTextOnDark)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(favorite.artist)
                        .textStyle(.label, color: .secondaryTextOnDark)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private func cover(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
        } else {
            Rectangle()
                .fill(Color.albumPlaceholderColor)
                .overlay {
                    Image(systemName: "music.note")
                        .textStyle(.iconPlaceholder, color: .secondaryText)
                }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            Rectangle()
                .fill(Color.surfaceOnGradientStroke)
                .frame(height: Stroke.hairline)

            HStack {
                Text("Rate yours at beatrate.app")
                    .textStyle(.caption, color: .secondaryTextOnDark)

                Spacer()

                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "heart.fill")
                        .textStyle(.iconChip, color: .accentPrimary)
                    Text("\(albums.count) picks")
                        .textStyle(.captionEmphasis, color: .primaryTextOnDark)
                }
            }
        }
    }
}

#Preview {
    FavoritesShareCard(
        name: "Alex Rivera",
        albums: (0..<4).map {
            ResolvedFavorite(id: "\($0)", cover: nil, title: "Album Title \($0 + 1)", artist: "Artist Name")
        }
    )
}
