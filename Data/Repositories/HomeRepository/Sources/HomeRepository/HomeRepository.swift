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

public protocol HomeRepositoryProtocol: Sendable {
    func fetchHomeSections() async throws -> [HomeSection]
}

public actor HomeRepository: HomeRepositoryProtocol {
    public static let shared = HomeRepository()
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    let databaseFirebaseService: DatabaseFirebaseServiceProtocol
    let musicRepository: MusicRepositoryProtocol
    
    private var homeSections: [HomeSection] = []
    
    public init(databaseFirebaseService: DatabaseFirebaseServiceProtocol = DatabaseFirebaseService.shared,
                musicRepository: MusicRepositoryProtocol = MusicRepository.shared) {
        self.databaseFirebaseService = databaseFirebaseService
        self.musicRepository = musicRepository
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        let firebaseSections = try await databaseFirebaseService.fetchSections()
        
        var newHomeSections: [HomeSection] = []

        for section in firebaseSections {
            var albumModels: [AlbumModel] = []

            for albumId in section.albums {
                do {
                    let album = try await self.musicRepository.getAlbumById(albumId)
                    albumModels.append(album)
                } catch {
                    Self.logger.error("Album not found for id: \(albumId) — \(error)")
                }
            }

            let homeSection = HomeSection(sectionName: section.name, albums: albumModels)
            newHomeSections.append(homeSection)
        }
        
        // Update the cached sections
        self.homeSections = newHomeSections
        return self.homeSections
    }
}
