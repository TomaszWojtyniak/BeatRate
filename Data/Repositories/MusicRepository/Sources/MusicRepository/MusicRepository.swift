//
//  MusicRepository.swift
//  MusicRepository
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import OSLog
import Analytics
import MusicKitService
import FirebaseService
import Models

struct AlbumNotFoundError: Error {
    let id: String
    
    var errorDescription: String? {
        return "Album with ID '\(id)' was not found"
    }
}

public protocol MusicRepositoryProtocol: Sendable {
    func requestMusicAuthorization() async -> Bool
    func getAlbumById(_ id: String) async throws -> AlbumModel
    func fetchHomeSections() async throws -> [HomeSection]
}

public actor MusicRepository: MusicRepositoryProtocol {
    public static let shared = MusicRepository()
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    let musicKitService: MusicKitServiceProtocol
    let databaseFirebaseService: DatabaseFirebaseServiceProtocol
    
    private var isMusicKitAuthorized: Bool = false
    
    public init(musicKitService: MusicKitServiceProtocol = MusicKitService.shared,
                databaseFirebaseService: DatabaseFirebaseServiceProtocol = DatabaseFirebaseService.shared) {
        self.musicKitService = musicKitService
        self.databaseFirebaseService = databaseFirebaseService
    }
    
    public func requestMusicAuthorization() async -> Bool {
        if isMusicKitAuthorized  {
            return true
        }
        
        let status = await musicKitService.requestMusicAuthorization()
        
        switch status {
        case .authorized:
            isMusicKitAuthorized = true
            return true
        case .notDetermined:
            Self.logger.info("Error getting Apple Music Authorization: Not determined")
            return false
        case .restricted:
            Self.logger.info("Error getting Apple Music Authorization: Restricted")
            return false
        case .denied:
            Self.logger.info("Error getting Apple Music Authorization: Denied")
            return false
        default:
            Self.logger.info("Error getting Apple Music Authorization: Unknown (New case)")
            return false
        }
    }
    
    public func getAlbumById(_ id: String) async throws -> AlbumModel {
        guard let album = try await self.musicKitService.fetchAlbum(by: id) else {
            throw AlbumNotFoundError(id: id)
        }
        return album
    }
    
    public func fetchHomeSections() async throws -> [HomeSection] {
        let firebaseSections = try await databaseFirebaseService.fetchSections()
        
        var homeSections: [HomeSection] = []

        for section in firebaseSections {
            var albumModels: [AlbumModel] = []

            for albumId in section.albums {
                do {
                    let album = try await getAlbumById(albumId)
                    albumModels.append(album)
                } catch {
                    Self.logger.error("Album not found for id: \(albumId) — \(error)")
                }
            }

            let homeSection = HomeSection(sectionName: section.name, albums: albumModels)
            homeSections.append(homeSection)
        }
        
        return homeSections
    }
}
