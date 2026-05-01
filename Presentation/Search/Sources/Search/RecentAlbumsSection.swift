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
                    .font(.system(.subheadline))
                    .foregroundStyle(Color.secondaryText)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recent")
                        .font(.system(.title3, weight: .bold))
                        .tracking(-0.4)

                    Spacer()

                    if onClear != nil {
                        Button {
                            showClearAlert = true
                        } label: {
                            Text("Clear")
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(albums) { album in
                        Button {
                            onAlbumTap(album)
                        } label: {
                            SearchAlbumRow(album: album)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if album.id != albums.last?.id {
                            Divider()
                                .padding(.leading, 90)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.vertical, 6)
                .roundedMaterialBackground()
                .padding(.horizontal, 16)

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
