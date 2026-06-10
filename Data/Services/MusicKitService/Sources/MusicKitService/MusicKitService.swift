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
    func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData]
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
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: musicId)

        // The track list is fetched as raw Apple Music API JSON instead of via the
        // `.tracks` extended property: MusicKit's decoder logs a spurious
        // "[Model] No catalogID..." console error for every track it decodes.
        async let tracksTask = fetchTracks(albumId: id)

        let response = try await request.response()

        if let album = response.items.first {
            let coverUrl = album.artwork?.url(width: Constants.albumCoverSize, height: Constants.albumCoverSize)
            let genre: String? = album.genreNames.first

            return AppleMusicAlbumData(
                id: album.id.rawValue,
                title: album.title,
                artist: album.artistName,
                coverUrl: coverUrl,
                releaseDate: album.releaseDate,
                genre: genre,
                tracks: try await tracksTask,
                recordLabel: album.recordLabelName,
                copyright: album.copyright,
                appleMusicUrl: album.url
            )
        } else {
            return nil
        }
    }

    /// Fetches an album's tracks through the Apple Music API `tracks` relationship
    /// endpoint, following pagination until the full list is collected.
    private func fetchTracks(albumId: String) async throws -> [Models.Track] {
        let countryCode = try await currentCountryCode()

        var components = URLComponents()
        components.scheme = AppleMusicAPI.scheme
        components.host = AppleMusicAPI.host
        components.path = "/v1/catalog/\(countryCode)/albums/\(albumId)/tracks"
        components.queryItems = [URLQueryItem(name: "limit", value: String(Constants.trackPageLimit))]

        var tracks: [Models.Track] = []
        var nextURL = components.url

        while let url = nextURL {
            let response = try await MusicDataRequest(urlRequest: URLRequest(url: url)).response()
            let page = try JSONDecoder().decode(AppleMusicTracksPage.self, from: response.data)

            for resource in page.data {
                tracks.append(Models.Track(
                    id: resource.id,
                    title: resource.attributes.name,
                    trackNumber: resource.attributes.trackNumber,
                    discNumber: resource.attributes.discNumber,
                    duration: resource.attributes.durationInMillis.map { TimeInterval($0) / 1000 },
                    isExplicit: resource.attributes.contentRating == AppleMusicAPI.explicitRating
                ))
            }

            nextURL = page.next.map { next in
                var nextComponents = URLComponents()
                nextComponents.scheme = AppleMusicAPI.scheme
                nextComponents.host = AppleMusicAPI.host
                return nextComponents.url.flatMap { URL(string: next, relativeTo: $0) }
            } ?? nil
        }

        return tracks
    }

    private var cachedCountryCode: String?

    private func currentCountryCode() async throws -> String {
        if let cachedCountryCode {
            return cachedCountryCode
        }
        let countryCode = try await MusicDataRequest.currentCountryCode
        cachedCountryCode = countryCode
        return countryCode
    }
    
    public func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] {
        guard !searchTerm.isEmpty else { return [] }

        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Album.self])
        request.limit = Constants.albumSearchLimit

        let response = try await request.response()

        return await withTaskGroup(of: AppleMusicAlbumData?.self) { group in
            for album in response.albums {
                group.addTask {
                    let coverUrl = album.artwork?.url(width: Constants.albumCoverSize, height: Constants.albumCoverSize)
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
    
    /// Returns the user's recently-played albums, most recent first.
    public func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData] {
        var request = MusicRecentlyPlayedContainerRequest()
        // Apple Music caps the recently-played limit at 10
        request.limit = Constants.albumRecentLimit

        let response = try await request.response()
        return response.items.compactMap { item -> AppleMusicAlbumData? in
            guard case let .album(album) = item else { return nil }
            return AppleMusicAlbumData(
                id: album.id.rawValue,
                title: album.title,
                artist: album.artistName,
                coverUrl: album.artwork?.url(width: Constants.albumCoverSize, height: Constants.albumCoverSize),
                releaseDate: album.releaseDate,
                genre: album.genreNames.first
            )
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
    
    private struct Constants {
        static let albumCoverSize: Int = 300
        static let albumSearchLimit: Int = 20
        static let albumRecentLimit: Int = 10
        // Maximum the relationship endpoint accepts per page
        static let trackPageLimit: Int = 300
    }
}

private nonisolated enum AppleMusicAPI {
    static let scheme = "https"
    static let host = "api.music.apple.com"
    static let explicitRating = "explicit"
}

/// Minimal shape of one page of the Apple Music API `albums/{id}/tracks` payload.
private nonisolated struct AppleMusicTracksPage: Decodable {
    let data: [Resource]
    let next: String?

    struct Resource: Decodable {
        let id: String
        let attributes: Attributes

        struct Attributes: Decodable {
            let name: String
            let trackNumber: Int?
            let discNumber: Int?
            let durationInMillis: Int?
            let contentRating: String?
        }
    }
}
