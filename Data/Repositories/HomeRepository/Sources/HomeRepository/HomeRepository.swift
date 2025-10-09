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
    func saveAlbumRating(albumId: String, rating: Double) async throws
    func getCachedAlbum(albumId: String) async throws -> AlbumModel?
}

public actor HomeRepository: HomeRepositoryProtocol {
    public static let shared = HomeRepository()

    let databaseFirebaseService: DatabaseFirebaseServiceProtocol
    let musicRepository: MusicRepositoryProtocol
    let swiftDataManager: SwiftDataManager

    private var homeSections: [HomeSection] = []

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
        guard let currentUserId = try await swiftDataManager.getCurrentUserId(), !currentUserId.isEmpty else {
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

    public func saveAlbumRating(albumId: String, rating: Double) async throws {
        guard let currentUserId = try await swiftDataManager.getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.homeRepository.error("Cannot save rating: User not logged in")
            throw HomeRepositoryError.albumDataMismatch
        }

        // Write to Firebase and update cache
        try await writeAndCacheUserRating(albumId: albumId, userId: currentUserId, rating: rating)
    }

    public func getCachedAlbum(albumId: String) async throws -> AlbumModel? {
        return try await swiftDataManager.getCachedAlbum(id: albumId)
    }
    
    // MARK: - Private Helper Methods

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
        var newHomeSections: [HomeSection] = []

        for section in firebaseSections {
            let albumModels = try await fetchAlbumsForSection(albumIds: await section.albums)
            let homeSection = await HomeSection(sectionName: section.name, albums: albumModels)
            newHomeSections.append(homeSection)
        }

        return newHomeSections
    }

    /// Fetches albums for a section, trying cache first then fetching from remote
    private func fetchAlbumsForSection(albumIds: [String]) async throws -> [AlbumModel] {
        var albumModels: [AlbumModel] = []

        for albumId in albumIds {
            do {
                // Try cache first
                if let cachedAlbum = try await swiftDataManager.getCachedAlbum(id: albumId) {
                    albumModels.append(cachedAlbum)
                } else {
                    // Fetch and cache album
                    let album = try await fetchAndCacheAlbum(albumId: albumId)
                    albumModels.append(album)
                }
            } catch {
                Logger.homeRepository.error("Album not found for id: \(albumId) — \(error)")
            }
        }

        return albumModels
    }

    /// Fetches album from MusicKit and Firebase, validates, and caches it
    private func fetchAndCacheAlbum(albumId: String) async throws -> AlbumModel {
        // Fetch from MusicKit and Firebase in parallel
        async let appleMusicAlbumTask = self.musicRepository.getAlbumDataById(albumId)
        async let firebaseAlbumDataTask = self.readAndCacheAlbumData(albumId: albumId)

        let musicData = try await appleMusicAlbumTask
        var firebaseData = try await firebaseAlbumDataTask

        // If no Firebase data exists, create it with default values
        if firebaseData == nil {
            firebaseData = try await createFirebaseAlbumData(for: albumId, musicData: musicData)
        }

        guard let validFirebaseData = firebaseData else {
            throw HomeRepositoryError.albumDataMismatch
        }

        // Build album model
        let album = await AlbumModel(
            id: albumId,
            appleMusicAlbumData: musicData,
            firebaseAlbumData: validFirebaseData
        )

        // Validate album data matches
        try await validateAlbumData(album)

        // Cache the fetched album
        try await swiftDataManager.cacheAlbum(id: albumId, album: album)

        return album
    }

    /// Creates new Firebase album data from MusicKit data
    private func createFirebaseAlbumData(for albumId: String, musicData: AppleMusicAlbumData) async throws -> FirebaseAlbumData {
        Logger.homeRepository.info("Creating new Firebase album entry for: \(albumId)")

        let newFirebaseData = await FirebaseAlbumData(
            artist: musicData.artist,
            avgRating: nil,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000),
            ratingCount: 0,
            title: musicData.title
        )

        // Write to Firebase and update cache
        try await self.writeAndCacheAlbumData(albumId: albumId, data: newFirebaseData)

        return newFirebaseData
    }

    /// Validates that Firebase and MusicKit data match for an album
    private func validateAlbumData(_ album: AlbumModel) async throws {
        let firebaseTitle = await album.firebaseAlbumData?.title
        let firebaseArtist = await album.firebaseAlbumData?.artist
        let musicTitle = await album.appleMusicAlbumData.title
        let musicArtist = await album.appleMusicAlbumData.artist

        if firebaseTitle != musicTitle || firebaseArtist != musicArtist {
            let albumId = await album.id
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
    private func writeAndCacheUserRating(albumId: String, userId: String, rating: Double) async throws {
        // Save rating and get calculated avgRating/ratingCount back
        let (avgRating, ratingCount) = try await databaseFirebaseService.saveUserRating(userId: userId, albumId: albumId, rating: rating)

        // Cache the user rating
        try await swiftDataManager.cacheUserRating(albumId: albumId, rating: rating)

        // Update cache with new avgRating and ratingCount (no extra fetch needed)
        if let cachedAlbum = try await swiftDataManager.getCachedAlbum(id: albumId)?.firebaseAlbumData {
            let updatedFirebaseData = await FirebaseAlbumData(
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
