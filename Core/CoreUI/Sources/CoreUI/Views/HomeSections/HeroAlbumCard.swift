//
//  HeroAlbumCard.swift
//  CoreUI
//
//  Featured "hero" album card for the top of the Home feed.
//  Gradient-tinted background, soft glow, large cover with depth shadows,
//  uppercase kicker, big title, artist, and a "Listen & Rate" pill.
//

import SwiftUI
import Models

public struct HeroAlbumCard: View {
    let album: AlbumModel
    let kicker: String
    let onTap: () -> Void

    public init(album: AlbumModel, kicker: String = "Featured · New Release", onTap: @escaping () -> Void) {
        self.album = album
        self.kicker = kicker
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Soft glow blob top-right for depth
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 220, height: 220)
                    .blur(radius: 40)
                    .offset(x: 50, y: -50)

                HStack(spacing: 16) {
                    AsyncImage(url: album.appleMusicAlbumData.coverUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.albumPlaceholderColor)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .appShadow(.high)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(kicker.uppercased())
                            .font(.system(.caption2, design: .monospaced, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(Color.white.opacity(0.85))

                        Text(album.appleMusicAlbumData.title)
                            .font(.system(size: 22, weight: .bold))
                            .tracking(-0.4)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color.white)
                            .padding(.top, 2)

                        Text(album.appleMusicAlbumData.artist)
                            .font(.system(.subheadline))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineLimit(1)

                        // "Listen & Rate" pill
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Listen & Rate")
                                .font(.system(.caption, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.20))
                        )
                        .padding(.top, 10)
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .background(
                LinearGradient(
                    colors: [Color.accentPrimary, Color.accentPrimaryDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                // Inner top-edge highlight for depth
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .appShadow(.accentLift)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HeroAlbumCard(album: AlbumModel.albumPlaceholder, onTap: {})
        .padding()
        .meshBackground()
}
