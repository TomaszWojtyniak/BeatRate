//
//  AccountRepository.swift
//  AccountRepository
//
//  Created by Tomasz Wojtyniak on 15/01/2026.
//

import Foundation
import OSLog
import Analytics
import Models
import HomeRepository
import FirebaseService
import SwiftDataManager

public protocol AccountRepositoryProtocol: Sendable {
    func getUserRatedAlbums() async throws -> [AlbumModel]
}

public actor AccountRepository: AccountRepositoryProtocol {
    public static let shared = AccountRepository()

    private let homeRepository: HomeRepositoryProtocol
    private let databaseFirebaseService: DatabaseFirebaseServiceProtocol
    private let swiftDataManager: SwiftDataManagerProtocol

    // Performance optimization: Cache user ID to avoid repeated MainActor hops
    private var cachedUserId: String?
    private var userIdCacheTime: Date?
    private let userIdCacheDuration: TimeInterval = 300 // 5 minutes

    public init(homeRepository: HomeRepositoryProtocol = HomeRepository.shared,
                databaseFirebaseService: DatabaseFirebaseServiceProtocol = DatabaseFirebaseService.shared,
                swiftDataManager: SwiftDataManagerProtocol = SwiftDataManager.shared) {
        self.homeRepository = homeRepository
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

        // Fetch albums in parallel using task group with order preservation
        return await withTaskGroup(of: (order: Int, album: AlbumModel?).self) { group in
            for (index, albumId) in albumIds.enumerated() {
                group.addTask {
                    do {
                        // Try cache first
                        if let cachedAlbum = try await self.homeRepository.getCachedAlbum(albumId: albumId) {
                            return (order: index, album: cachedAlbum)
                        } else {
                            // Fetch and cache album
                            let album = try await self.homeRepository.fetchAndCacheAlbum(albumId: albumId)
                            return (order: index, album: album)
                        }
                    } catch {
                        Logger.accountRepository.error("Failed to fetch rated album: \(albumId) — \(error)")
                        return (order: index, album: nil)
                    }
                }
            }

            // Collect results and sort by original order to maintain timestamp sorting
            var results: [(order: Int, album: AlbumModel?)] = []
            for await result in group {
                results.append(result)
            }

            return results
                .sorted { $0.order < $1.order }
                .compactMap { $0.album }
        }
    }

    // MARK: - Private Helpers

    private func getCurrentUserId() async throws -> String? {
        // Check if cached user ID is still valid
        if let cached = cachedUserId,
           let cacheTime = userIdCacheTime,
           Date().timeIntervalSince(cacheTime) < userIdCacheDuration {
            return cached
        }

        // Fetch and cache
        let userId = try await swiftDataManager.getCurrentUserId()
        cachedUserId = userId
        userIdCacheTime = Date()
        return userId
    }
}
