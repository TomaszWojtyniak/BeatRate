//
//  HomeRepository.swift
//  HomeRepository
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import Foundation
import OSLog
import Analytics
import Models
import MusicRepository
import FirebaseService
import SwiftDataManager

private enum HomeRepositoryError: Error {
    case albumDataMismatch
}

public protocol HomeRepositoryProtocol: Sendable {
    func fetchHomeSections() async throws -> [HomeSection]
    func getUserRating(albumId: String) async throws -> Double?
    func saveAlbumRating(albumId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws
    func getUserRatedAlbums() async throws -> [AlbumModel]
    func getCachedAlbum(albumId: String) async throws -> AlbumModel?
    func getFirebaseAlbumData(albumId: String) async throws -> FirebaseAlbumData?
    func invalidateUserCache() async
}

public actor HomeRepository: HomeRepositoryProtocol {
    public static let shared = HomeRepository()

    let databaseFirebaseService: DatabaseFirebaseServiceProtocol
    let musicRepository: MusicRepositoryProtocol
    let swiftDataManager: SwiftDataManager

    private var homeSections: [HomeSection] = []

    // Performance optimization: Cache user ID to avoid repeated MainActor hops
    private var cachedUserId: String?
    private var userIdCacheTime: Date?
    private let userIdCacheDuration: TimeInterval = 300 // 5 minutes

    public init(databaseFirebaseService: DatabaseFirebaseServiceProtocol = DatabaseFirebaseService.shared,
                musicRepository: MusicRepositoryProtocol = MusicRepository.shared,
                swiftDataManager: SwiftDataManager = .shared) {
        self.databaseFirebaseService = databaseFirebaseService
        self.musicRepository = musicRepository
        self.swiftDataManager = swiftDataManager
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        // Try to get from cache first if valid
        if let cachedSections = try await getCachedSectionsIfValid() {
            self.homeSections = cachedSections
            return cachedSections
        }
        // Fetch fresh data if cache miss or invalid
        let firebaseSections = try await databaseFirebaseService.fetchSections()
        let newHomeSections = try await buildHomeSections(from: firebaseSections)

        // Update cache with new sections
        try await swiftDataManager.cacheSections(newHomeSections)

        // Update the cached sections
        self.homeSections = newHomeSections
        return self.homeSections
    }
    
    public func getUserRating(albumId: String) async throws -> Double? {
        // Use cached user ID to avoid MainActor hop
        guard let currentUserId = try await getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.homeRepository.info("Cannot get rating: User not logged in")
            return nil
        }

        // Check cache first (7-day validity)
        if let cachedRating = try await swiftDataManager.getCachedUserRating(albumId: albumId) {
            Logger.homeRepository.info("Returning cached user rating for album: \(albumId)")
            return cachedRating
        }

        // Fetch from Firebase and cache
        return try await readAndCacheUserRating(albumId: albumId, userId: currentUserId)
    }

    public func saveAlbumRating(albumId: String, rating: Double, albumMetadata: (artist: String, title: String)? = nil) async throws {
        // Use cached user ID to avoid MainActor hop
        guard let currentUserId = try await getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.homeRepository.error("Cannot save rating: User not logged in")
            throw HomeRepositoryError.albumDataMismatch
        }

        // Write to Firebase and update cache
        try await writeAndCacheUserRating(albumId: albumId, userId: currentUserId, rating: rating, albumMetadata: albumMetadata)
    }

    public func getUserRatedAlbums() async throws -> [AlbumModel] {
        // Use cached user ID to avoid MainActor hop
        guard let currentUserId = try await getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.homeRepository.info("Cannot get rated albums: User not logged in")
            return []
        }

        // Fetch rated album IDs from Firebase
        let albumIds = try await databaseFirebaseService.getUserRatedAlbumIds(userId: currentUserId)

        // Fetch albums in parallel using task group
        return await withTaskGroup(of: AlbumModel?.self) { group in
            for albumId in albumIds {
                group.addTask {
                    do {
                        // Try cache first
                        if let cachedAlbum = try await self.swiftDataManager.getCachedAlbum(id: albumId) {
                            return cachedAlbum
                        } else {
                            // Fetch and cache album
                            return try await self.fetchAndCacheAlbum(albumId: albumId)
                        }
                    } catch {
                        Logger.homeRepository.error("Failed to fetch rated album: \(albumId) — \(error)")
                        return nil
                    }
                }
            }

            var results: [AlbumModel] = []
            for await album in group {
                if let album = album {
                    results.append(album)
                }
            }
            return results
        }
    }

    public func getCachedAlbum(albumId: String) async throws -> AlbumModel? {
        return try await swiftDataManager.getCachedAlbum(id: albumId)
    }

    public func getFirebaseAlbumData(albumId: String) async throws -> FirebaseAlbumData? {
        return try await databaseFirebaseService.fetchAlbumData(albumId: albumId)
    }

    /// Invalidate cached user ID (call on logout)
    public func invalidateUserCache() async {
        cachedUserId = nil
        userIdCacheTime = nil
    }

    // MARK: - Private Helper Methods

    /// Get current user ID with caching to reduce MainActor hops
    /// Performance: Caches user ID for 5 minutes to avoid repeated SwiftDataManager calls
    private func getCurrentUserId() async throws -> String? {
        // Check cache first
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

    /// Returns cached sections if cache is valid, nil otherwise
    private func getCachedSectionsIfValid() async throws -> [HomeSection]? {
        guard await swiftDataManager.isCacheValid() else {
            return nil
        }

        do {
            let cachedSections = try await swiftDataManager.getCachedSections()
            if !cachedSections.isEmpty {
                Logger.homeRepository.info("Returning cached sections")
                return cachedSections
            }
        } catch {
            Logger.homeRepository.error("Failed to get cached sections: \(error)")
        }

        return nil
    }

    /// Builds home sections from Firebase section data
    private func buildHomeSections(from firebaseSections: [FirebaseAlbumSection]) async throws -> [HomeSection] {
        // Use task group to fetch all sections in parallel
        return try await withThrowingTaskGroup(of: (order: Int, section: HomeSection).self) { group in
            for (index, section) in firebaseSections.enumerated() {
                group.addTask {
                    try Task.checkCancellation()
                    let albumModels = try await self.fetchAlbumsForSection(albumIds: section.albums)
                    let homeSection = HomeSection(sectionName: section.name, albums: albumModels)
                    return (order: index, section: homeSection)
                }
            }

            // Collect results and sort by original order
            var results: [(order: Int, section: HomeSection)] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.order < $1.order }.map { $0.section }
        }
    }

    /// Fetches albums for a section, trying cache first then fetching from remote
    private func fetchAlbumsForSection(albumIds: [String]) async throws -> [AlbumModel] {
        // Use task group to fetch all albums in parallel
        return await withTaskGroup(of: (order: Int, album: AlbumModel?).self) { group in
            for (index, albumId) in albumIds.enumerated() {
                group.addTask {
                    do {
                        try Task.checkCancellation()
                        // Try cache first
                        if let cachedAlbum = try await self.swiftDataManager.getCachedAlbum(id: albumId) {
                            return (order: index, album: cachedAlbum)
                        } else {
                            // Fetch and cache album
                            let album = try await self.fetchAndCacheAlbum(albumId: albumId)
                            return (order: index, album: album)
                        }
                    } catch {
                        Logger.homeRepository.error("Album not found for id: \(albumId) — \(error)")
                        return (order: index, album: nil)
                    }
                }
            }

            // Collect results, sort by original order, and filter out nil albums
            var results: [(order: Int, album: AlbumModel?)] = []
            for await result in group {
                results.append(result)
            }

            return results
                .compactMap { $0.album }
        }
    }

    /// Fetches album from MusicKit and Firebase, validates, and caches it
    private func fetchAndCacheAlbum(albumId: String) async throws -> AlbumModel {
        // Fetch from MusicKit and Firebase in parallel
        async let appleMusicAlbumTask = self.musicRepository.getAlbumDataById(albumId)
        async let firebaseAlbumDataTask = self.readAndCacheAlbumData(albumId: albumId)

        let musicData = try await appleMusicAlbumTask
        var firebaseData = try? await firebaseAlbumDataTask  // Use try? to handle missing albums

        // If no Firebase data exists, create it with default values
        if firebaseData == nil {
            Logger.homeRepository.info("No Firebase data found for album: \(albumId), creating new entry")
            firebaseData = try await createFirebaseAlbumData(for: albumId, musicData: musicData)
        }

        guard let validFirebaseData = firebaseData else {
            throw HomeRepositoryError.albumDataMismatch
        }

        // Build album model
        let album = AlbumModel(
            id: albumId,
            appleMusicAlbumData: musicData,
            firebaseAlbumData: validFirebaseData
        )

        // Validate album data matches (no await needed - synchronous validation)
        try validateAlbumData(album)

        // Cache the fetched album
        try await swiftDataManager.cacheAlbum(id: albumId, album: album)

        return album
    }

    /// Creates new Firebase album data from MusicKit data
    private func createFirebaseAlbumData(for albumId: String, musicData: AppleMusicAlbumData) async throws -> FirebaseAlbumData {
        Logger.homeRepository.info("Creating new Firebase album entry for: \(albumId)")

        let newFirebaseData = FirebaseAlbumData(
            artist: musicData.artist,
            avgRating: 0,  // Set to 0 for new albums with no ratings
            createdAt: Int64(Date().timeIntervalSince1970 * 1000),
            ratingCount: 0,
            title: musicData.title
        )

        // Write to Firebase and update cache
        try await self.writeAndCacheAlbumData(albumId: albumId, data: newFirebaseData)

        return newFirebaseData
    }

    /// Validates that Firebase and MusicKit data match for an album
    /// Performance: Made nonisolated and synchronous - no suspension point needed for simple validation
    private nonisolated func validateAlbumData(_ album: AlbumModel) throws {
        let firebaseTitle = album.firebaseAlbumData?.title
        let firebaseArtist = album.firebaseAlbumData?.artist
        let musicTitle = album.appleMusicAlbumData.title
        let musicArtist = album.appleMusicAlbumData.artist

        if firebaseTitle != musicTitle || firebaseArtist != musicArtist {
            let albumId = album.id
            Logger.homeRepository.error("Wrong album data for album id: \(albumId)")
            throw HomeRepositoryError.albumDataMismatch
        }
    }

    // MARK: - Private Cache Wrapper Methods

    /// Reads album data from Firebase and caches it
    private func readAndCacheAlbumData(albumId: String) async throws -> FirebaseAlbumData? {
        let data = try await databaseFirebaseService.fetchAlbumData(albumId: albumId)
        // Data is cached when full album is cached via cacheAlbum()
        return data
    }

    /// Writes album data to Firebase and updates cache
    private func writeAndCacheAlbumData(albumId: String, data: FirebaseAlbumData) async throws {
        try await databaseFirebaseService.saveAlbumData(albumId: albumId, albumData: data)
        try await swiftDataManager.updateCachedAlbum(albumId: albumId, firebaseData: data)
        Logger.homeRepository.info("Wrote and cached album data for: \(albumId)")
    }

    /// Reads user rating from Firebase and caches it
    private func readAndCacheUserRating(albumId: String, userId: String) async throws -> Double? {
        let rating = try await databaseFirebaseService.getUserRating(userId: userId, albumId: albumId)
        if let rating = rating {
            try await swiftDataManager.cacheUserRating(albumId: albumId, rating: rating)
            Logger.homeRepository.info("Read and cached user rating for album: \(albumId)")
        }
        return rating
    }

    /// Writes user rating to Firebase and updates cache (including recalculated album avgRating)
    private func writeAndCacheUserRating(albumId: String, userId: String, rating: Double, albumMetadata: (artist: String, title: String)?) async throws {
        // Save rating and get calculated avgRating/ratingCount back
        let (avgRating, ratingCount) = try await databaseFirebaseService.saveUserRating(
            userId: userId,
            albumId: albumId,
            rating: rating,
            albumMetadata: albumMetadata
        )

        // Cache the user rating
        try await swiftDataManager.cacheUserRating(albumId: albumId, rating: rating)

        // Update cache with new avgRating and ratingCount (no extra fetch needed)
        if let cachedAlbum = try await swiftDataManager.getCachedAlbum(id: albumId)?.firebaseAlbumData {
            let updatedFirebaseData = FirebaseAlbumData(
                artist: cachedAlbum.artist,
                avgRating: avgRating,
                createdAt: cachedAlbum.createdAt,
                ratingCount: ratingCount,
                title: cachedAlbum.title
            )
            try await swiftDataManager.updateCachedAlbum(albumId: albumId, firebaseData: updatedFirebaseData)
        }

        Logger.homeRepository.info("Wrote and cached user rating for album: \(albumId), new avg: \(avgRating)")
    }
}
