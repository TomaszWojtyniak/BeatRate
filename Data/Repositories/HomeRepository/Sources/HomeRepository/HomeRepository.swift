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
    case userIdMissing
}

public protocol HomeRepositoryProtocol: Sendable {
    func fetchHomeSections() async throws -> [HomeSection]
    func saveAlbumRating(albumId: String, rating: Double) async throws
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
        if await swiftDataManager.isCacheValid() {
            do {
                let cachedSections = try await swiftDataManager.getCachedSections()
                if !cachedSections.isEmpty {
                    Logger.homeRepository.info("Returning cached sections")
                    self.homeSections = cachedSections
                    return cachedSections
                }
            } catch {
                Logger.homeRepository.error("Failed to get cached sections: \(error)")
            }
        }
        
        // Fetch fresh data if cache miss or invalid
        let firebaseSections = try await databaseFirebaseService.fetchSections()
        
        var newHomeSections: [HomeSection] = []

        for section in firebaseSections {
            var albumModels: [AlbumModel] = []

            for albumId in await section.albums {
                do {
                    // Try cache first
                    if let cachedAlbum = try await swiftDataManager.getCachedAlbum(id: albumId) {
                        albumModels.append(cachedAlbum)
                    } else {
                        // Fetch from MusicKit and Firebase in parallel
                        async let appleMusicAlbumTask = self.musicRepository.getAlbumDataById(albumId)
                        async let firebaseAlbumDataTask = self.databaseFirebaseService.fetchAlbumData(albumId: albumId)

                        let musicData = try await appleMusicAlbumTask
                        var firebaseData = try await firebaseAlbumDataTask

                        // If no Firebase data exists, create it with default values
                        if firebaseData == nil {
                            Logger.homeRepository.info("Creating new Firebase album entry for: \(albumId)")
                            let newFirebaseData = await FirebaseAlbumData(
                                artist: musicData.artist,
                                avgRating: nil,
                                createdAt: Int64(Date().timeIntervalSince1970 * 1000),
                                ratingCount: 0,
                                title: musicData.title
                            )

                            // Save to Firebase
                            try await self.databaseFirebaseService.saveAlbumData(albumId: albumId, albumData: newFirebaseData)
                            firebaseData = newFirebaseData
                        }

                        guard let validFirebaseData = firebaseData else {
                            Logger.homeRepository.error("Failed to create Firebase data for album: \(albumId)")
                            continue
                        }

                        let album = await AlbumModel(
                            id: albumId,
                            appleMusicAlbumData: musicData,
                            firebaseAlbumData: validFirebaseData
                        )

                        let firebaseTitle = await album.firebaseAlbumData?.title
                        let firebaseArtist = await album.firebaseAlbumData?.artist
                        let musicTitle = await album.appleMusicAlbumData.title
                        let musicArtist = await album.appleMusicAlbumData.artist

                        if firebaseTitle != musicTitle || firebaseArtist != musicArtist {
                            Logger.homeRepository.error("Wrong album data for album id: \(albumId)")
                            continue
                        }

                        albumModels.append(album)

                        // Cache the fetched album
                        try await swiftDataManager.cacheAlbum(id: albumId, album: album)
                    }
                } catch {
                    Logger.homeRepository.error("Album not found for id: \(albumId) — \(error)")
                }
            }

            let homeSection = await HomeSection(sectionName: section.name, albums: albumModels)
            newHomeSections.append(homeSection)
        }
        
        // Update cache with new sections
        try await swiftDataManager.cacheSections(newHomeSections)
        
        // Update the cached sections
        self.homeSections = newHomeSections
        return self.homeSections
    }
    
    public func saveAlbumRating(albumId: String, rating: Double) async throws {
        guard let currentUserId = try await swiftDataManager.getCurrentUserId(), !currentUserId.isEmpty else {
            Logger.homeRepository.error("Cannot save rating: User not logged in")
            throw HomeRepositoryError.userIdMissing
        }
        try await databaseFirebaseService.saveUserRating(userId: currentUserId, albumId: albumId, rating: rating)
        // Invalidate cache to force refresh with new rating data on next fetch
        try await swiftDataManager.clearCache()

        Logger.homeRepository.info("Saved rating \(rating) for album: \(albumId), user: \(currentUserId)")
    }
}
