//
//  AlbumDetailsFooterView.swift
//  AlbumDetails
//

import SwiftUI
import Models
import CoreUI

struct AlbumDetailsFooterView: View {
    let album: AppleMusicAlbumData

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let url = album.appleMusicUrl {
                Link(destination: url) {
                    Label("Open in Apple Music", systemImage: "applelogo")
                        .textStyle(.bodyEmphasis, color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.appleMusicGradient, in: .capsule)
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
}

#Preview {
    AlbumDetailsFooterView(album: AppleMusicAlbumData(
        id: "1",
        title: "Title",
        artist: "Artist",
        coverUrl: nil,
        releaseDate: nil,
        genre: nil,
        recordLabel: "Example Records",
        copyright: "℗ 2024 Example Records",
        appleMusicUrl: URL(string: "https://music.apple.com")
    ))
    .padding()
    .meshBackground()
}
