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
    func fetchAlbum(by id: String) async throws -> AlbumModel?
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
    
    public func fetchAlbum(by id: String) async throws -> AlbumModel? {
        let musicId = createMusicItemID(from: id)
        var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: musicId)
        
        request.properties = [.genres, .tracks]
        
        let response = try await request.response()
        
        if let album = response.items.first {
            let coverUrl = album.artwork?.url(width: 300, height: 300)
            
            let genre: String? = album.genreNames.first
            return await AlbumModel(
                title: album.title,
                artist: album.artistName,
                coverUrl: coverUrl,
                releaseDate: album.releaseDate,
                genre: genre,
                rating: 7.8
            )
        } else {
            return nil
        }
    }
}
