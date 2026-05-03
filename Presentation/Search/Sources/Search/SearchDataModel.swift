//
//  SearchDataModel.swift
//  Search
//
//  Created by Claude on 25/10/2025.
//

import SwiftUI
import SearchUse
import Models

@MainActor
@Observable
public final class SearchDataModel {
    private let getSearchUseCase: GetSearchUseCaseProtocol
    private let getRecentAlbumsUseCase: GetRecentAlbumsUseCaseProtocol
    private let saveRecentAlbumUseCase: SaveRecentAlbumUseCaseProtocol
    private let clearRecentAlbumsUseCase: ClearRecentAlbumsUseCaseProtocol
    private var searchTask: Task<Void, Never>?

    public var albums: [AppleMusicAlbumData] = []
    public var recentAlbums: [AppleMusicAlbumData] = []
    public var isLoading: Bool = false

    public init(
        getSearchUseCase: GetSearchUseCaseProtocol = GetSearchUseCase(),
        getRecentAlbumsUseCase: GetRecentAlbumsUseCaseProtocol = GetRecentAlbumsUseCase(),
        saveRecentAlbumUseCase: SaveRecentAlbumUseCaseProtocol = SaveRecentAlbumUseCase(),
        clearRecentAlbumsUseCase: ClearRecentAlbumsUseCaseProtocol = ClearRecentAlbumsUseCase()
    ) {
        self.getSearchUseCase = getSearchUseCase
        self.getRecentAlbumsUseCase = getRecentAlbumsUseCase
        self.saveRecentAlbumUseCase = saveRecentAlbumUseCase
        self.clearRecentAlbumsUseCase = clearRecentAlbumsUseCase
    }

    public func loadRecentAlbums() async {
        recentAlbums = await getRecentAlbumsUseCase.fetchRecentAlbums()
    }

    public func searchAlbum(searchTerm: String) {
        // Cancel any existing search task
        searchTask?.cancel()

        guard !searchTerm.isEmpty else {
            albums = []
            isLoading = false
            return
        }

        isLoading = true

        // Create a new debounced search task
        searchTask = Task {
            // Wait 500ms before searching
            try? await Task.sleep(for: .milliseconds(500))

            // Check if task was cancelled while sleeping
            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            do {
                let results = try await getSearchUseCase.searchAlbums(searchTerm: searchTerm)

                // Check again if task was cancelled
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                albums = results
                isLoading = false
            } catch {
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                albums = []
                isLoading = false
            }
        }
    }
    
    public func saveRecentAlbum(_ album: AppleMusicAlbumData) {
        Task {
            await saveRecentAlbumUseCase.save(album: album)
            recentAlbums = await getRecentAlbumsUseCase.fetchRecentAlbums()
        }
    }

    public func clearRecentAlbums() {
        Task {
            await clearRecentAlbumsUseCase.clearAll()
            recentAlbums = []
        }
    }
}
