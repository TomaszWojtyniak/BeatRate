//
//  SearchDataModel.swift
//  Search
//
//  Created by Claude on 25/10/2025.
//

import SwiftUI
import SearchUse
import Models
import Analytics

@MainActor
@Observable
public final class SearchDataModel {
    private let getSearchUseCase: GetSearchUseCaseProtocol
    private let getRecentAlbumsUseCase: GetRecentAlbumsUseCaseProtocol
    private let saveRecentAlbumUseCase: SaveRecentAlbumUseCaseProtocol
    private let clearRecentAlbumsUseCase: ClearRecentAlbumsUseCaseProtocol
    private let analyticsManager: AnalyticsManager
    private var searchTask: Task<Void, Never>?

    public var albums: [AppleMusicAlbumData] = []
    public var artists: [AppleMusicArtistData] = []
    public var recentAlbums: [AppleMusicAlbumData] = []
    public var isLoading: Bool = false
    
    public var hasResults: Bool {
        !albums.isEmpty || !artists.isEmpty
    }

    public init(
        getSearchUseCase: GetSearchUseCaseProtocol = GetSearchUseCase(),
        getRecentAlbumsUseCase: GetRecentAlbumsUseCaseProtocol = GetRecentAlbumsUseCase(),
        saveRecentAlbumUseCase: SaveRecentAlbumUseCaseProtocol = SaveRecentAlbumUseCase(),
        clearRecentAlbumsUseCase: ClearRecentAlbumsUseCaseProtocol = ClearRecentAlbumsUseCase(),
        analyticsManager: AnalyticsManager = .shared
    ) {
        self.getSearchUseCase = getSearchUseCase
        self.getRecentAlbumsUseCase = getRecentAlbumsUseCase
        self.saveRecentAlbumUseCase = saveRecentAlbumUseCase
        self.clearRecentAlbumsUseCase = clearRecentAlbumsUseCase
        self.analyticsManager = analyticsManager
    }

    func track(_ event: AnalyticsEvent) {
        analyticsManager.log(event)
    }

    public func loadRecentAlbums() async {
        recentAlbums = await getRecentAlbumsUseCase.fetchRecentAlbums()
    }

    public func searchAlbum(searchTerm: String) {
        // Cancel any existing search task
        searchTask?.cancel()

        guard !searchTerm.isEmpty else {
            albums = []
            artists = []
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
                let results = try await getSearchUseCase.search(searchTerm: searchTerm)

                // Check again if task was cancelled
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                albums = results.albums
                artists = results.artists
                isLoading = false
                analyticsManager.log(.search(albumCount: albums.count, artistCount: artists.count))
            } catch {
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                albums = []
                artists = []
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
        analyticsManager.log(.recentClearConfirm)
        Task {
            await clearRecentAlbumsUseCase.clearAll()
            recentAlbums = []
        }
    }
}
