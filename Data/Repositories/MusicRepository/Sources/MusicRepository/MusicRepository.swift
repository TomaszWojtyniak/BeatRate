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
import Models

struct AlbumNotFoundError: Error {
    let id: String
    
    var errorDescription: String? {
        return "Album with ID '\(id)' was not found"
    }
}

public protocol MusicRepositoryProtocol: Sendable {
    func requestMusicAuthorization() async -> Bool
    func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
}

public actor MusicRepository: MusicRepositoryProtocol {
    public static let shared = MusicRepository()
    
    let musicKitService: MusicKitServiceProtocol
    
    private var isMusicKitAuthorized: Bool = false
    
    public init(musicKitService: MusicKitServiceProtocol = MusicKitService.shared) {
        self.musicKitService = musicKitService
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
            Logger.musicRepository.info("Error getting Apple Music Authorization: Not determined")
            return false
        case .restricted:
            Logger.musicRepository.info("Error getting Apple Music Authorization: Restricted")
            return false
        case .denied:
            Logger.musicRepository.info("Error getting Apple Music Authorization: Denied")
            return false
        default:
            Logger.musicRepository.info("Error getting Apple Music Authorization: Unknown (New case)")
            return false
        }
    }
    
    public func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData {
        guard let album = try await self.musicKitService.fetchAlbumData(by: id) else {
            throw AlbumNotFoundError(id: id)
        }
        return album
    }
    
    public func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] {
        Logger.musicRepository.info("Searching albums with query: '\(searchTerm)'")

        let albums = try await musicKitService.searchAlbums(searchTerm: searchTerm)
        Logger.musicRepository.info("Found \(albums.count) albums for query: '\(searchTerm)'")
        return albums
    }
}
