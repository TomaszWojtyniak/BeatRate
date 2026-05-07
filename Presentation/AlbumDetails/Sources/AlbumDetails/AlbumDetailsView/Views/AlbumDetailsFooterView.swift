//
//  AlbumDetailsFooterView.swift
//  AlbumDetails
//

import SwiftUI
import Models
import CoreUI
import CoreApp

struct AlbumDetailsFooterView: View {
    let album: AppleMusicAlbumData
    let playUrl: URL?
    let playLabel: String
    let playPlayer: MusicPlayer?

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let url = playUrl {
                Link(destination: url) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(playLabel)
                            .textStyle(.bodyEmphasis, color: .white)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.xs)
                    .frame(maxWidth: .infinity, minHeight: Size.signInButton)
                    .background(Capsule().fill(playerBackground))
                }
                .appShadow(.medium)
            }

            if album.recordLabel != nil || album.copyright != nil {
                VStack(spacing: Spacing.xxs) {
                    if let label = album.recordLabel {
                        Text(label)
                            .textStyle(.caption, color: .secondaryText)
                    }
                    if let copyright = album.copyright {
                        Text(copyright)
                            .textStyle(.caption, color: .secondaryText)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.md)
            }
        }
    }


    private var playerBackground: AnyShapeStyle {
        switch playPlayer {
        case .spotify: AnyShapeStyle(Color.spotifyGradient)
        default: AnyShapeStyle(Color.appleMusicGradient)
        }
    }
}

#Preview {
    AlbumDetailsFooterView(
        album: AppleMusicAlbumData(
            id: "1",
            title: "Title",
            artist: "Artist",
            coverUrl: nil,
            releaseDate: nil,
            genre: nil,
            recordLabel: "Example Records",
            copyright: "℗ 2024 Example Records",
            appleMusicUrl: URL(string: "https://music.apple.com")
        ),
        playUrl: URL(string: "https://music.apple.com"),
        playLabel: "Open in Apple Music",
        playPlayer: .appleMusic
    )
    .padding()
    .meshBackground()
}
