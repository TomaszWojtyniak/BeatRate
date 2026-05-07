//
//  MusicKitService.swift
//  MusicKitService
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import Analytics
import OSLog
import MusicKit
import Models

public struct MusicAuthorizationResult: Sendable {
    public let status: MusicAuthorization.Status
    public let hasSubscription: Bool

    public init(status: MusicAuthorization.Status, hasSubscription: Bool) {
        self.status = status
        self.hasSubscription = hasSubscription
    }
}

public protocol MusicKitServiceProtocol: Sendable {
    func requestMusicAuthorization() async -> MusicAuthorizationResult
    func isAuthorized() async -> Bool
    func isAuthorizationDetermined() async -> Bool
    func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData?
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
}

public actor MusicKitService: MusicKitServiceProtocol {
    public static let shared = MusicKitService()
    let analyticsManager: AnalyticsManager
    let crashLogger: CrashLogger
    
    private var canPlayAppleMusic: Bool = false

    public init(analyticsManager: AnalyticsManager = .shared,
                crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
    
    public func isAuthorized() async -> Bool {
        MusicAuthorization.currentStatus == .authorized
    }

    public func isAuthorizationDetermined() async -> Bool {
        MusicAuthorization.currentStatus != .notDetermined
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
            let tracks: [Models.Track]? = album.tracks?.map { track in
                Models.Track(
                    id: track.id.rawValue,
                    title: track.title,
                    trackNumber: track.trackNumber,
                    discNumber: track.discNumber,
                    duration: track.duration,
                    isExplicit: track.contentRating == .explicit
                )
            }

            return AppleMusicAlbumData(
                id: album.id.rawValue,
                title: album.title,
                artist: album.artistName,
                coverUrl: coverUrl,
                releaseDate: album.releaseDate,
                genre: genre,
                tracks: tracks,
                recordLabel: album.recordLabelName,
                copyright: album.copyright,
                appleMusicUrl: album.url
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

                    return AppleMusicAlbumData(
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
    
    public func requestMusicAuthorization() async -> MusicAuthorizationResult {
        let musicAuthorizationStatus = await MusicAuthorization.request()

        guard musicAuthorizationStatus == .authorized else {
            return await MusicAuthorizationResult(status: musicAuthorizationStatus, hasSubscription: false)
        }

        let subscription = await withTaskGroup(of: MusicSubscription?.self) { group in
            group.addTask {
                for await sub in MusicSubscription.subscriptionUpdates {
                    return sub
                }
                return nil
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }

        if let subscription {
            canPlayAppleMusic = subscription.canPlayCatalogContent
        }

        return await MusicAuthorizationResult(
            status: musicAuthorizationStatus,
            hasSubscription: canPlayAppleMusic
        )
    }
}
