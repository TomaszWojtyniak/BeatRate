//
//  AlbumDetailsDataModel.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 16/09/2025.
//

import Foundation
import SwiftUI
import HomeUseCases
import OSLog
import Models
import CoreUI
import CoreApp
import UIKit

@MainActor
@Observable
final class AlbumDetailsDataModel {
    private let getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol
    private let sessionManager: SessionManager
    private let musicPlayerManager: MusicPlayerManager

    var album: AlbumModel
    var myRating: Double = 0
    var isLoading = false
    var hasLoadedInitialRating = false
    var meshPrimary: Color?
    var meshSecondary: Color?
    var playUrl: URL?
    private var previousRating: Double = 0

    init(
        album: AlbumModel,
        sessionManager: SessionManager = .shared,
        musicPlayerManager: MusicPlayerManager = .shared,
        getAlbumDetailsUseCase: GetAlbumDetailsUseCaseProtocol = GetAlbumDetailsUseCase()
    ) {
        self.album = album
        self.getAlbumDetailsUseCase = getAlbumDetailsUseCase
        self.sessionManager = sessionManager
        self.musicPlayerManager = musicPlayerManager
    }

    var playPlayer: MusicPlayer? {
        musicPlayerManager.current
    }

    /// Guests see the rating stars but can't set one — the view routes their taps
    /// to ``requestLoginForRating()`` instead.
    var isLoggedIn: Bool {
        sessionManager.isLoggedIn
    }

    func requestLoginForRating() {
        sessionManager.requestLogin(reason: .rating)
    }

    var playLabel: String {
        switch playPlayer {
        case .spotify: "Play on Spotify"
        default: "Play on Apple Music"
        }
    }

    /// Resolves the deep link behind the play button.
    ///
    /// Play-through is an account feature, so this gates *every* player — the
    /// guard sits above the switch rather than inside a branch, which is how the
    /// Apple Music case previously leaked a button to guests.
    func resolvePlayUrl() async {
        guard isLoggedIn else {
            playUrl = nil
            return
        }

        switch playPlayer {
        case .spotify:
            let id = await getAlbumDetailsUseCase.searchSpotifyAlbumId(
                name: album.appleMusicAlbumData.title,
                artist: album.appleMusicAlbumData.artist
            )
            guard let id else {
                playUrl = nil
                return
            }
            let appUrl = URL(string: "spotify:album:\(id)")
            let webUrl = URL(string: "https://open.spotify.com/album/\(id)")
            if let appUrl, UIApplication.shared.canOpenURL(appUrl) {
                playUrl = appUrl
            } else {
                playUrl = webUrl
            }

        case .appleMusic, .none:
            playUrl = album.appleMusicAlbumData.appleMusicUrl
        }
    }

    func fetchUserRating() async -> Double? {
        isLoading = true
        defer { isLoading = false }

        do {
            return try await self.getAlbumDetailsUseCase.getUserRating(albumId: album.id)
        } catch let error {
            Logger.albumDetails.error("error fetching user rating: \(error)")
            return nil
        }
    }

    func saveAlbumRating(rating: Double) async {
        // Store previous rating for rollback in case of error
        previousRating = myRating

        do {
            // Pass album metadata (artist, title) for new albums
            let metadata = (artist: album.appleMusicAlbumData.artist, title: album.appleMusicAlbumData.title)

            try await self.getAlbumDetailsUseCase.saveAlbumRating(
                albumId: album.id,
                rating: rating,
                albumMetadata: metadata
            )
            Logger.albumDetails.info("Successfully saved rating: \(rating)")

            // Refresh album data to get updated avgRating from cache
            await refreshAlbumData()
        } catch let error {
            Logger.albumDetails.error("error saving album: \(error)")
            // Rollback to previous rating on error
            myRating = previousRating
        }
    }

    /// Extracts two dominant colours from the cover artwork and stores them
    /// pre-softened (≈18% alpha) so they can be used directly as mesh halos.
    /// No-op if the album has no cover URL or extraction fails.
    func loadMeshColors() async {
        guard let coverUrl = album.appleMusicAlbumData.coverUrl,
              meshPrimary == nil else { return }

        if let colors = await ArtworkColors.extract(from: coverUrl) {
            meshPrimary = colors.primary.opacity(0.65)
            meshSecondary = colors.secondary.opacity(0.55)
        }
    }

    func loadTracksIfNeeded() async {
        guard album.appleMusicAlbumData.tracks?.isEmpty != false else { return }

        do {
            self.album = try await getAlbumDetailsUseCase.fetchFullAlbum(albumId: album.id)
        } catch {
            Logger.albumDetails.error("Failed to backfill tracks for album \(self.album.id): \(error)")
        }
    }

    func refreshAlbumData() async {
        do {
            if let updatedAlbum = try await getAlbumDetailsUseCase.getUpdatedAlbum(albumId: album.id) {
                self.album = updatedAlbum
                Logger.albumDetails.info("Refreshed album data with updated avgRating")
            }
        } catch {
            Logger.albumDetails.error("Failed to refresh album data: \(error)")
        }
    }
}
