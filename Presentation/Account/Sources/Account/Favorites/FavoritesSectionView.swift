//
//  FavoritesSectionView.swift
//  Account
//
//  Created by Claude on 22/07/2026.
//

import SwiftUI
import Models
import CoreUI

/// The Account "Favorites" card content: a header (title, heart count, Edit and
/// Share affordances) over a fixed row of four slots. Filled slots show artwork
/// that pushes AlbumDetails; empty slots are dashed "+" tiles that open the
/// manager. Rendered without a background — the caller wraps it in
/// `.roundedMaterialBackground()`, matching the Ratings section.
struct FavoritesSectionView: View {

    private static let slotCount = AccountDataModel.maxFavorites

    let albums: [AlbumModel]
    let canShare: Bool
    @Binding var selectedAlbum: AlbumModel?
    let onManage: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            slots
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Text("Favorites")
                .textStyle(.titleSection)

            Spacer(minLength: Spacing.xs)

            if canShare {
                Button(action: onShare) {
                    Text("Share")
                        .textStyle(.captionEmphasis, color: .accentPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share favorites")
            }
        }
    }

    // MARK: - Slots

    private var slots: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Spacing.sm),
                count: Self.slotCount
            ),
            spacing: Spacing.sm
        ) {
            ForEach(0..<Self.slotCount, id: \.self) { index in
                if index < albums.count {
                    filledSlot(albums[index])
                } else {
                    emptySlot
                }
            }
        }
    }

    private func filledSlot(_ album: AlbumModel) -> some View {
        Button {
            selectedAlbum = album
        } label: {
            AlbumCoverImage(url: album.appleMusicAlbumData.coverUrl)
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .appShadow(.low)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(album.appleMusicAlbumData.title)
    }

    private var emptySlot: some View {
        Button(action: onManage) {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .strokeBorder(
                    Color.surfaceStrokeSelected,
                    style: StrokeStyle(lineWidth: Stroke.thin, dash: [Spacing.xs])
                )
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "plus")
                        .textStyle(.iconAction, color: .accentPrimary)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add favorite album")
    }
}
