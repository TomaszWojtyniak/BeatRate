//
//  FavoritesShareView.swift
//  Account
//
//  Created by Claude on 22/07/2026.
//

import SwiftUI
import Models
import CoreUI

/// Full-screen presentation of the shareable favorites card. Pre-loads the four
/// cover images, renders the card to a crisp PNG, and offers it through the
/// system share sheet (which itself includes "Save Image" to Photos).
struct FavoritesShareView: View {

    let name: String
    let albums: [AlbumModel]

    @Environment(\.dismiss) private var dismiss
    @State private var resolved: [ResolvedFavorite] = []
    @State private var renderedImage: UIImage?

    var body: some View {
        ZStack {
            Color.scrim.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                closeButton

                cardPreview

                shareButton
            }
            .padding(Spacing.lg)
        }
        .task { await prepare() }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .textStyle(.iconPlaceholder, foreground: Color.secondaryTextOnDark)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var cardPreview: some View {
        GeometryReader { geo in
            // Scale to fit the available box in BOTH axes so the whole card is
            // visible and never overflows onto the share button below. Capped at
            // 1 so the card is never upscaled past its native size.
            let scale = min(
                1,
                geo.size.width / FavoritesShareCard.canvasWidth,
                geo.size.height / FavoritesShareCard.canvasHeight
            )
            FavoritesShareCard(name: name, albums: resolved)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let renderedImage {
            let shareImage = Image(uiImage: renderedImage)
            ShareLink(
                item: shareImage,
                preview: SharePreview("My favorites", image: shareImage)
            ) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share image")
                }
                .textStyle(.bodyEmphasis, color: .primaryTextOnDark)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(Capsule().fill(Color.accentPrimaryGradient))
                .appShadow(.accentGlow)
            }
        } else {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryTextOnDark))
                .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Preparation

    private func prepare() async {
        resolved = await loadResolved(albums)
        renderedImage = render()
    }

    /// Four small, likely cache-warm fetches (the covers were just shown in the
    /// section), loaded in input order so the card matches the row.
    private func loadResolved(_ albums: [AlbumModel]) async -> [ResolvedFavorite] {
        var out: [ResolvedFavorite] = []
        for album in albums {
            let data = album.appleMusicAlbumData
            out.append(
                ResolvedFavorite(
                    id: album.id,
                    cover: await loadImage(data.coverUrl),
                    title: data.title,
                    artist: data.artist
                )
            )
        }
        return out
    }

    private func loadImage(_ url: URL?) async -> UIImage? {
        guard let url else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    @MainActor
    private func render() -> UIImage? {
        let renderer = ImageRenderer(content: FavoritesShareCard(name: name, albums: resolved))
        renderer.scale = 3
        return renderer.uiImage
    }
}
