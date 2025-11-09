//
//  RecentAlbumsSection.swift
//  Search
//
//  Created by Tomasz Wojtyniak on 09/11/2025.
//

import SwiftUI
import Models

struct RecentAlbumsSection: View {
    let albums: [AppleMusicAlbumData]
    let onAlbumTap: (AppleMusicAlbumData) -> Void
    let onClear: (() -> Void)?

    @State private var showClearAlert = false

    var body: some View {
        if albums.isEmpty {
            ContentUnavailableView("Search music", systemImage: "magnifyingglass")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent")
                        .font(.title3)

                    Spacer()

                    if onClear != nil {
                        Button("Clear", role: .cancel) {
                            showClearAlert = true
                        }
                        .font(.subheadline)
                        .bold()
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    ForEach(albums) { album in
                        Button {
                            onAlbumTap(album)
                        } label: {
                            SearchAlbumRow(album: album)
                                .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                        if album.id != albums.last?.id {
                            Divider()
                                .padding(.leading, 84)
                        }
                    }
                }
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
