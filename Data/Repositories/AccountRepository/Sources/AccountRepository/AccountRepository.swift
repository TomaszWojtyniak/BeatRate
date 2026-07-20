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
        let musicData = try await musicRepository.fetchRecentlyListenedAlbums(for: player)

        var seenIds = Set<String>()
        let albums = musicData.compactMap { data -> AlbumModel? in
            guard !seenIds.contains(data.id) else { return nil }
            seenIds.insert(data.id)
            return AlbumModel(id: data.id, appleMusicAlbumData: data, firebaseAlbumData: nil)
        }

        Logger.accountRepository.info("Loaded \(albums.count) recently listened albums for \(player.rawValue)")
        return albums
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

    /// Deliberately uncached. This has a single caller (`getUserRatedAlbums`), so a
    /// TTL cache here saved one MainActor hop per Account-tab load — and in exchange
    /// held the previous account's id after a logout, listing user A's rated albums
    /// to user B when they signed in inside the TTL window. Read it fresh.
    private func getCurrentUserId() async throws -> String? {
        try await swiftDataManager.getCurrentUserId()
    }
}
