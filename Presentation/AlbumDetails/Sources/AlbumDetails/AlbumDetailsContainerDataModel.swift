//
//  AlbumDetailsContainerDataModel.swift
//  AlbumDetails
//

import Foundation
import HomeUseCases
import Models
import Analytics

/// Loads an album by id for screens that only have the id (deep links, search).
@MainActor
@Observable
final class AlbumDetailsContainerDataModel {
    enum LoadState {
        case loading
        case loaded(AlbumModel)
        case failed(String)
    }

    let albumId: String
    private(set) var state: LoadState = .loading

    private let getAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol
    private let analyticsManager: AnalyticsManager

    init(albumId: String, getAlbumByIdUseCase: GetAlbumByIdUseCaseProtocol, analyticsManager: AnalyticsManager) {
        self.albumId = albumId
        self.getAlbumByIdUseCase = getAlbumByIdUseCase
        self.analyticsManager = analyticsManager
    }

    func load() async {
        state = .loading
        do {
            let album = try await getAlbumByIdUseCase.fetchAlbum(id: albumId)
            CrashLogger.log("Loaded album \(albumId), tracks: \(album.appleMusicAlbumData.tracks.map { "\($0.count)" } ?? "none yet")")
            state = .loaded(album)
        } catch {
            CrashLogger.report("AlbumDetails", "load \(albumId) failed: \(error)", to: .albumDetails)
            state = .failed(String(localized: .albumErrorMessage))
        }
    }

    func retry() async {
        analyticsManager.log(.retryTap(screen: .albumDetails))
        await load()
    }
}
