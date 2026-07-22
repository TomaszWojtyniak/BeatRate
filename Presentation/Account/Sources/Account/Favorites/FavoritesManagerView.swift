//
//  FavoritesManagerView.swift
//  Account
//
//  Created by Claude on 22/07/2026.
//

import SwiftUI
import Models
import CoreUI

/// Sheet for curating favorites: search albums to add, reorder and remove up to
/// four. Edits happen on a working copy; Done commits via `onSave`, Cancel
/// discards. When the search field is empty the favorites editor is shown;
/// typing switches to tappable search results.
struct FavoritesManagerView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var model: FavoritesManagerModel
    private let onSave: ([AlbumModel]) async -> Void

    init(initial: [AlbumModel], onSave: @escaping ([AlbumModel]) async -> Void) {
        _model = State(initialValue: FavoritesManagerModel(initial: initial))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.searchText.isEmpty {
                    favoritesEditor
                } else {
                    searchResults
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.searchText, prompt: "Search albums to add")
            .onChange(of: model.searchText) { model.search() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let final = model.working
                        Task { await onSave(final) }
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Favorites editor (reorder + delete)

    private var favoritesEditor: some View {
        List {
            Section {
                if model.working.isEmpty {
                    Text("Search above to add up to \(AccountDataModel.maxFavorites) albums.")
                        .textStyle(.caption)
                } else {
                    ForEach(model.working) { album in
                        FavoriteAlbumRow(album: album.appleMusicAlbumData)
                    }
                    .onMove { model.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { model.remove(atOffsets: $0) }
                }
            } header: {
                Text("\(model.working.count)/\(AccountDataModel.maxFavorites)")
            }
        }
        // Always-on edit mode surfaces both reorder handles and delete controls —
        // this list exists only to manage favorites, so there's nothing else to tap.
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Search results (tap to add)

    private var searchResults: some View {
        List {
            if model.isSearching && model.results.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            ForEach(model.results) { data in
                Button {
                    model.add(data)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        FavoriteAlbumRow(album: data)
                        addIndicator(for: data)
                    }
                }
                .buttonStyle(.plain)
                .disabled(model.contains(data.id) || !model.canAddMore)
            }
        }
    }

    @ViewBuilder
    private func addIndicator(for data: AppleMusicAlbumData) -> some View {
        if model.contains(data.id) {
            Image(systemName: "checkmark.circle.fill")
                .textStyle(.iconAction, color: .accentPrimary)
        } else if model.canAddMore {
            Image(systemName: "plus.circle")
                .textStyle(.iconAction, color: .accentPrimary)
        } else {
            Image(systemName: "plus.circle")
                .textStyle(.iconAction, foreground: .tertiary)
        }
    }
}

/// Compact album row (cover + title + artist) for the manager's lists. The Search
/// feature's own row is package-private, so this mirrors it with shared tokens.
private struct FavoriteAlbumRow: View {
    let album: AppleMusicAlbumData

    var body: some View {
        HStack(spacing: Spacing.sm) {
            AlbumCoverImage(url: album.coverUrl, placeholderIconStyle: nil)
                .frame(width: Size.thumbnailSmall, height: Size.thumbnailSmall)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .appShadow(.low)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(album.title)
                    .textStyle(.bodyEmphasis)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(album.artist)
                    .textStyle(.caption)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
    }
}
