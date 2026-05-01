//
//  RecentAlbumsSection.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 09/11/2025.
//

import SwiftUI
import Models
import CoreUI

struct RecentAlbumsSection: View {
    let albums: [AppleMusicAlbumData]
    let onAlbumTap: (AppleMusicAlbumData) -> Void
    let onClear: (() -> Void)?

    @State private var showClearAlert = false

    var body: some View {
        if albums.isEmpty {
            ContentUnavailableView {
                Label("Search music", systemImage: "magnifyingglass")
                    .foregroundStyle(Color.primaryText)
            } description: {
                Text("Find albums and rate everything you listen to.")
                    .textStyle(.body)
                    .foregroundStyle(Color.secondaryText)
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recent")
                        .textStyle(.titleSection)

                    Spacer()

                    if onClear != nil {
                        Button {
                            showClearAlert = true
                        } label: {
                            Text("Clear")
                                .textStyle(.captionEmphasis, color: .accentPrimary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)

                VStack(spacing: 0) {
                    ForEach(albums) { album in
                        Button {
                            onAlbumTap(album)
                        } label: {
                            SearchAlbumRow(album: album)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.xxs)
                        }
                        .buttonStyle(.plain)

                        if album.id != albums.last?.id {
                            Divider()
                                .padding(.leading, 90)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .roundedMaterialBackground()
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
            .alert("Clear Recent Searches", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    onClear?()
                }
            } message: {
                Text("Are you sure you want to clear all recent albums?")
            }
        }
    }
}

#Preview {
    RecentAlbumsSection(
        albums: [.albumPlaceholder, .albumPlaceholder],
        onAlbumTap: { _ in },
        onClear: { }
    )
}
