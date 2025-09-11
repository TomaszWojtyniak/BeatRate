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

public protocol HomeRepositoryProtocol: Sendable {
    func fetchHomeSections() async throws -> [HomeSection]
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
                    if let cachedAlbum = try await swiftDataManager.getCachedAlbum(albumId: albumId) {
                        albumModels.append(cachedAlbum)
                    } else {
                        // Fetch from MusicKit if not in cache
                        let album = try await self.musicRepository.getAlbumById(albumId)
                        albumModels.append(album)
                        
                        // Cache the fetched album
                        try await swiftDataManager.cacheAlbum(albumId: albumId, album: album)
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
}
