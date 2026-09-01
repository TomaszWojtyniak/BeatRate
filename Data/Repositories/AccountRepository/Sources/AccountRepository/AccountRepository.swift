//
//  AccountRepository.swift
//  AccountRepository
//
//  Created by Tomasz Wojtyniak on 15/01/2026.
//

import Foundation
import OSLog
import Analytics
import CoreApp
import Models
import HomeRepository
import MusicRepository
import FirebaseService
import SwiftDataManager

public protocol AccountRepositoryProtocol: Sendable {
    func getUserRatedAlbums() async throws -> [AlbumModel]
    func getRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AlbumModel]
    func getAlbumSections(recentlyListenedFor player: MusicPlayer?) async throws -> (rated: [AlbumModel], recentlyListened: [AlbumModel])
    func getFavoriteAlbums() async throws -> [AlbumModel]
    func setFavoriteAlbums(albumIds: [String]) async throws
}

public actor AccountRepository: AccountRepositoryProtocol {
    public static let shared = AccountRepository()

    private let homeRepository: HomeRepositoryProtocol
    private let musicRepository: MusicRepositoryProtocol
    private let databaseFirebaseService: DatabaseFirebaseServiceProtocol
    private let swiftDataManager: SwiftDataManagerProtocol

    public init(homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
                musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
                databaseFirebaseService: DatabaseFirebaseServiceProtocol = DatabaseFirebaseService.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.homeRepository = homeRepository
        self.musicRepository = musicRepository
        self.databaseFirebaseService = databaseFirebaseService
        self.swiftDataManager = swiftDataManager
    }

    public func getUserRatedAlbums() async throws -> [AlbumModel] {
        // Use cached user ID to avoid MainActor hop
        guard let currentUserId = try await getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.accountRepository.info("Cannot get rated albums: User not logged in")
            return []
        }

        // Fetch rated album IDs from Firebase (already sorted by timestamp, newest first)
        let albumIds = try await databaseFirebaseService.getUserRatedAlbumIds(userId: currentUserId)

        return await albums(forIds: albumIds)
    }

    public func getRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AlbumModel] {
        let ratings = await userRatings() ?? [:]
        return try await recentlyListened(for: player, ratings: ratings)
    }

    /// Loads the Account album sections (rated + recently listened) from a **single**
    /// `user_ratings` read: the rated section takes its newest-first ordering from
    /// it, and the recently-listened section takes its rating badges from it —
    /// instead of each section reading the node independently.
    public func getAlbumSections(recentlyListenedFor player: MusicPlayer?) async throws -> (rated: [AlbumModel], recentlyListened: [AlbumModel]) {
        guard let userId = try await getCurrentUserId(), !userId.isEmpty else {
            // Not logged in: no rated albums; recently listened is MusicKit-only.
            return (rated: [], recentlyListened: (try? await recentlyListened(for: player, ratings: [:])) ?? [])
        }

        let entries = (try? await databaseFirebaseService.getUserRatingsSorted(userId: userId)) ?? []
        let ratingsMap = Dictionary(entries.map { ($0.albumId, $0.rating) }, uniquingKeysWith: { first, _ in first })

        async let ratedTask = albums(forIds: entries.map(\.albumId))
        async let recentTask = recentlyListened(for: player, ratings: ratingsMap)
        return await (rated: ratedTask, recentlyListened: (try? await recentTask) ?? [])
    }

    /// Fetches recently-listened albums and badges each with the caller-supplied
    /// ratings. Rethrows so the caller can tell "this failed" from "this is
    /// empty" — collapsing the two made rate-limited fetches look like an empty
    /// listening history. A `nil` player (none selected) is genuinely empty.
    private func recentlyListened(for player: MusicPlayer?, ratings: [String: Double]) async throws -> [AlbumModel] {
        guard let player else { return [] }
        let musicData = try await musicRepository.fetchRecentlyListenedAlbums(for: player)
        var seenIds = Set<String>()
        let albums = musicData.compactMap { data -> AlbumModel? in
            guard seenIds.insert(data.id).inserted else { return nil }
            return AlbumModel(id: data.id, appleMusicAlbumData: data, firebaseAlbumData: nil, userRating: ratings[data.id])
        }
        Logger.accountRepository.info("Loaded \(albums.count) recently listened albums for \(player.rawValue)")
        return albums
    }

    /// The user's `albumId -> rating` map, for badging albums that arrive from a
    /// rating-less source. One Firebase read; `nil` on failure (e.g. offline) so
    /// callers gracefully fall back to unrated.
    private func userRatings() async -> [String: Double]? {
        guard let userId = (try? await getCurrentUserId()) ?? nil, !userId.isEmpty else {
            return nil
        }
        return try? await databaseFirebaseService.getAllUserRatings(userId: userId)
    }

    public func getFavoriteAlbums() async throws -> [AlbumModel] {
        guard let currentUserId = try await getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.accountRepository.info("Cannot get favorites: User not logged in")
            return []
        }

        let albumIds = try await databaseFirebaseService.getFavoriteAlbumIds(userId: currentUserId)
        return await hydratedFavorites(forIds: albumIds)
    }

    public func setFavoriteAlbums(albumIds: [String]) async throws {
        guard let currentUserId = try await getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.accountRepository.info("Cannot save favorites: User not logged in")
            return
        }

        try await databaseFirebaseService.saveFavoriteAlbumIds(userId: currentUserId, albumIds: albumIds)
    }

    // MARK: - Private Helpers

    /// Caps parallel cache-miss fetches (MusicKit + Firebase per album) when
    /// hydrating long rated-album lists.
    private nonisolated static let maxConcurrentAlbumFetches = 5

    /// Hydrates a list of album IDs into full `AlbumModel`s
    private func albums(forIds albumIds: [String]) async -> [AlbumModel] {
        await albumIds.concurrentCompactMap(maxConcurrent: Self.maxConcurrentAlbumFetches) { albumId in
            do {
                // Try cache first, then fetch and cache
                if let cachedAlbum = try await self.homeRepository.getCachedAlbum(albumId: albumId) {
                    return cachedAlbum
                } else {
                    return try await self.homeRepository.fetchAndCacheAlbum(albumId: albumId)
                }
            } catch {
                Logger.accountRepository.error("Failed to fetch album: \(albumId) — \(error)")
                return nil
            }
        }
    }

    /// Like `albums(forIds:)` but **lossless**: an ID that can't be fetched
    /// (offline + cache miss) yields a minimal placeholder instead of being
    /// dropped. Favorites are re-saved from this list, so dropping an ID here
    /// would silently and permanently delete a favorite that was merely
    /// transiently unavailable. The placeholder carries the real ID, so it
    /// survives the round-trip and AlbumDetails backfills it by ID on tap.
    private func hydratedFavorites(forIds albumIds: [String]) async -> [AlbumModel] {
        await albumIds.concurrentCompactMap(maxConcurrent: Self.maxConcurrentAlbumFetches) { albumId in
            do {
                if let cachedAlbum = try await self.homeRepository.getCachedAlbum(albumId: albumId) {
                    return cachedAlbum
                } else {
                    return try await self.homeRepository.fetchAndCacheAlbum(albumId: albumId)
                }
            } catch {
                Logger.accountRepository.error("Favorite \(albumId) unavailable; keeping placeholder — \(error)")
                return AlbumModel(
                    id: albumId,
                    appleMusicAlbumData: AppleMusicAlbumData(
                        id: albumId, title: "", artist: "", coverUrl: nil, releaseDate: nil, genre: nil
                    ),
                    firebaseAlbumData: nil
                )
            }
        }
    }

    private func getCurrentUserId() async throws -> String? {
        try await swiftDataManager.getCurrentUserId()
    }
}
