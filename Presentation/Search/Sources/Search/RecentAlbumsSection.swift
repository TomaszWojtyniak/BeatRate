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
                Label(String(localized: .searchRecentEmptyTitle), systemImage: "magnifyingglass")
                    .foregroundStyle(Color.primaryText)
            } description: {
                Text(.searchRecentEmptyMessage)
                    .textStyle(.body, color: .secondaryText)
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(.searchRecentTitle)
                        .textStyle(.titleSection)

                    Spacer()

                    if onClear != nil {
                        Button {
                            showClearAlert = true
                        } label: {
                            Text(.searchRecentClear)
                                .textStyle(.captionEmphasis, color: .accentPrimary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)

                VStack(spacing: 0) {
                    ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                        Button {
                            onAlbumTap(album)
                        } label: {
                            SearchAlbumRow(album: album)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.xxs)
                        }
                        .buttonStyle(.plain)

                        if index < albums.count - 1 {
                            Divider()
                                .padding(.leading, Size.thumbnailSmall + Spacing.sm + Spacing.lg)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .roundedMaterialBackground()
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
            .alert(String(localized: .searchRecentClearTitle), isPresented: $showClearAlert) {
                Button(String(localized: .searchRecentCancel), role: .cancel) { }
                Button(String(localized: .searchRecentClear), role: .destructive) {
                    onClear?()
                }
            } message: {
                Text(.searchRecentClearMessage)
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
