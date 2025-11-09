//
//  MusicKitService.swift
//  MusicKitService
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Analytics
import OSLog
import MusicKit
import Models

public protocol MusicKitServiceProtocol: Sendable {
    func requestMusicAuthorization() async -> MusicAuthorization.Status
    func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData?
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
}

public actor MusicKitService: MusicKitServiceProtocol {
    public static let shared = MusicKitService()
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    
    public init(analyticsManager: AnalyticsManager = .shared,
                crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    public func requestMusicAuthorization() async -> MusicAuthorization.Status {
        return await MusicAuthorization.request()
    }
    
    private func createMusicItemID(from stringID: String) -> MusicItemID {
        return MusicItemID(stringID)
    }
    
    public func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData? {
        let musicId = createMusicItemID(from: id)
        var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: musicId)
        
        request.properties = [.genres, .tracks]
        
        let response = try await request.response()
        
        if let album = response.items.first {
            let coverUrl = album.artwork?.url(width: 300, height: 300)
            let genre: String? = album.genreNames.first

            return await AppleMusicAlbumData(
                id: album.id.rawValue,
                title: album.title,
                artist: album.artistName,
                coverUrl: coverUrl,
                releaseDate: album.releaseDate,
                genre: genre
            )
        } else {
            return nil
        }
    }
    
    public func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] {
        guard !searchTerm.isEmpty else { return [] }

        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Album.self])
        request.limit = 20

        let response = try await request.response()

        return await withTaskGroup(of: AppleMusicAlbumData?.self) { group in
            for album in response.albums {
                group.addTask {
                    let coverUrl = album.artwork?.url(width: 300, height: 300)
                    let genre: String? = album.genreNames.first

                    return await AppleMusicAlbumData(
                        id: album.id.rawValue,
                        title: album.title,
                        artist: album.artistName,
                        coverUrl: coverUrl,
                        releaseDate: album.releaseDate,
                        genre: genre
                    )
                }
            }

            var results: [AppleMusicAlbumData] = []
            for await albumData in group {
                if let albumData = albumData {
                    results.append(albumData)
                }
            }
            return results
        }
    }
}
