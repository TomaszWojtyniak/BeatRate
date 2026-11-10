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
    private(set) var searchTask: Task<Void, Never>?
    private let debounce: Duration

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
        analyticsManager: AnalyticsManager = .shared,
        debounce: Duration = .milliseconds(500)
    ) {
        self.debounce = debounce
        self.getSearchUseCase = getSearchUseCase
        self.getRecentAlbumsUseCase = getRecentAlbumsUseCase
        self.saveRecentAlbumUseCase = saveRecentAlbumUseCase
        self.clearRecentAlbumsUseCase = clearRecentAlbumsUseCase
        self.analyticsManager = analyticsManager
    }

    func track(_ event: AnalyticsEvent) {
        analyticsManager.log(event)
    }

    /// Opening an album from results or recents tracks it and moves it to the top of recents.
    @discardableResult
    func albumTapped(_ album: AppleMusicAlbumData, source: AlbumTapSource) -> Task<Void, Never> {
        analyticsManager.log(.albumTap(source: source, albumId: album.id))
        return saveRecentAlbum(album)
    }

    func artistTapped(_ artist: AppleMusicArtistData) {
        analyticsManager.log(.artistTap(artistId: artist.id))
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
            try? await Task.sleep(for: debounce)

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
    
    @discardableResult
    public func saveRecentAlbum(_ album: AppleMusicAlbumData) -> Task<Void, Never> {
        Task {
            await saveRecentAlbumUseCase.save(album: album)
            recentAlbums = await getRecentAlbumsUseCase.fetchRecentAlbums()
        }
    }

    @discardableResult
    public func clearRecentAlbums() -> Task<Void, Never> {
        analyticsManager.log(.recentClearConfirm)
        return Task {
            await clearRecentAlbumsUseCase.clearAll()
            recentAlbums = []
        }
    }
}
