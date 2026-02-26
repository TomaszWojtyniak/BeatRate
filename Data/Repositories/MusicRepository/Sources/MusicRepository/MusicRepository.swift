//
//  MusicRepository.swift
//  MusicRepository
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

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

public struct MusicAuthorizationInfo: Sendable {
    public let isAuthorized: Bool
    public let hasSubscription: Bool

    public init(isAuthorized: Bool, hasSubscription: Bool) {
        self.isAuthorized = isAuthorized
        self.hasSubscription = hasSubscription
    }
}

public protocol MusicRepositoryProtocol: Sendable {
    func requestMusicAuthorization() async -> MusicAuthorizationInfo
    func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
}

public actor MusicRepository: MusicRepositoryProtocol {
    public static let shared = MusicRepository()
    
    let musicKitService: MusicKitServiceProtocol
    
    private var isMusicKitAuthorized: Bool = false
    private var cachedHasSubscription: Bool = false
    
    public init(musicKitService: MusicKitServiceProtocol = MusicKitService.shared) {
        self.musicKitService = musicKitService
    }
    
    public func requestMusicAuthorization() async -> MusicAuthorizationInfo {
        if isMusicKitAuthorized {
            return await MusicAuthorizationInfo(isAuthorized: true, hasSubscription: cachedHasSubscription)
        }

        let result = await musicKitService.requestMusicAuthorization()

        let isAuthorized: Bool
        switch await result.status {
        case .authorized:
            isMusicKitAuthorized = true
            cachedHasSubscription = await result.hasSubscription
            isAuthorized = true
        case .notDetermined:
            Logger.musicRepository.info("Error getting Apple Music Authorization: Not determined")
            isAuthorized = false
        case .restricted:
            Logger.musicRepository.info("Error getting Apple Music Authorization: Restricted")
            isAuthorized = false
        case .denied:
            Logger.musicRepository.info("Error getting Apple Music Authorization: Denied")
            isAuthorized = false
        default:
            Logger.musicRepository.info("Error getting Apple Music Authorization: Unknown (New case)")
            isAuthorized = false
        }

        return await MusicAuthorizationInfo(
            isAuthorized: isAuthorized,
            hasSubscription: result.hasSubscription
        )
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
