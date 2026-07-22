//
//  FavoritesManagerModel.swift
//  Account
//
//  Created by Claude on 22/07/2026.
//

import SwiftUI
import Models
import SearchUse

/// Backs the favorites manager sheet. Holds a *working copy* of the favorites so
/// edits can be committed on Done or discarded on Cancel, plus debounced album
/// search reused from `GetSearchUseCase`.
@MainActor
@Observable
final class FavoritesManagerModel {
    private let getSearchUseCase: GetSearchUseCaseProtocol
    private var searchTask: Task<Void, Never>?

    var working: [AlbumModel]
    var searchText: String = ""
    var results: [AppleMusicAlbumData] = []
    var isSearching: Bool = false

    var canAddMore: Bool { working.count < AccountDataModel.maxFavorites }

    init(initial: [AlbumModel],
         getSearchUseCase: GetSearchUseCaseProtocol = GetSearchUseCase()) {
        self.working = initial
        self.getSearchUseCase = getSearchUseCase
    }

    func contains(_ id: String) -> Bool {
        working.contains { $0.id == id }
    }

    func add(_ data: AppleMusicAlbumData) {
        guard canAddMore, !contains(data.id) else { return }
        working.append(AlbumModel(id: data.id, appleMusicAlbumData: data, firebaseAlbumData: nil))
    }

    func remove(atOffsets offsets: IndexSet) {
        working.remove(atOffsets: offsets)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        working.move(fromOffsets: source, toOffset: destination)
    }

    /// Debounced search (500ms) mirroring `SearchDataModel`. Empty text clears
    /// results so the sheet falls back to the favorites editor.
    func search() {
        searchTask?.cancel()

        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { isSearching = false; return }

            do {
                let found = try await getSearchUseCase.search(searchTerm: term)
                guard !Task.isCancelled else { isSearching = false; return }
                results = found.albums
            } catch {
                guard !Task.isCancelled else { isSearching = false; return }
                results = []
            }
            isSearching = false
        }
    }
}
