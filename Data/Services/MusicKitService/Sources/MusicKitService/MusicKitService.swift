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

public actor MusicKitService: MusicKitServiceProtocol {
    public static let shared = MusicKitService()

    let analyticsManager: AnalyticsManager

    private var canPlayAppleMusic: Bool = false
    /// The user's storefront country code, cached for the actor's lifetime.
    private var cachedStorefront: String?

    public init(analyticsManager: AnalyticsManager = .shared) {
        self.analyticsManager = analyticsManager
    }

    // MARK: - Authorization

    public func isAuthorized() async -> Bool {
        MusicAuthorization.currentStatus == .authorized
    }

    public func isAuthorizationDetermined() async -> Bool {
        MusicAuthorization.currentStatus != .notDetermined
    }

    public func requestMusicAuthorization() async -> MusicAuthorizationResult {
        let status = await MusicAuthorization.request()

        guard status == .authorized else {
            return await MusicAuthorizationResult(status: status, hasSubscription: false)
        }

        if let subscription = await currentSubscription(timeout: Constants.subscriptionTimeout) {
            canPlayAppleMusic = subscription.canPlayCatalogContent
        }

        return await MusicAuthorizationResult(status: status, hasSubscription: canPlayAppleMusic)
    }

    /// First value from `MusicSubscription.subscriptionUpdates`, or nil when none
    /// arrives within `timeout` — the stream never yields on accounts without an
    /// Apple Music capability, so the caller must not await it unbounded.
    private func currentSubscription(timeout: Duration) async -> MusicSubscription? {
        await withTaskGroup(of: MusicSubscription?.self) { group in
            group.addTask {
                for await subscription in MusicSubscription.subscriptionUpdates {
                    return subscription
                }
                return nil
            }

            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - Album Lookup

    public func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData? {
        // Tracks come from the raw API rather than the `.tracks` extended property:
        // MusicKit's decoder logs a spurious "[Model] No catalogID..." console
        // error for every track it decodes.
        async let tracks = fetchTracks(albumId: id)

        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()

        guard let album = response.items.first else { return nil }
        
        let loadedTracks: [Models.Track]?
        do {
            loadedTracks = try await tracks
        } catch {
            Logger.musicService.error("Failed to fetch tracks for album \(id): \(error)")
            loadedTracks = nil
        }
        return albumData(from: album, tracks: loadedTracks)
    }

    /// Fetches an album's tracks through the raw `albums/{id}/tracks` relationship
    /// endpoint, following pagination until the full list is collected.
    private func fetchTracks(albumId: String) async throws -> [Models.Track] {
        var tracks: [Models.Track] = []
        var nextURL: URL? = AppleMusicAPI.albumTracks(storefront: try await storefront(), albumId: albumId)

        while let url = nextURL {
            let response = try await MusicDataRequest(urlRequest: URLRequest(url: url)).response()
            let page = try JSONDecoder().decode(AppleMusicTracksPage.self, from: response.data)
            tracks.append(contentsOf: page.tracks)
            nextURL = page.next.flatMap(AppleMusicAPI.nextPage)
        }

        return tracks
    }

    private func storefront() async throws -> String {
        if let cachedStorefront {
            return cachedStorefront
        }
        let storefront = try await MusicDataRequest.currentCountryCode
        cachedStorefront = storefront
        return storefront
    }

    // MARK: - Artist Lookup

    public func fetchArtistData(byId artistId: String) async throws -> AppleMusicArtistData? {
        let request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(artistId))
        let response = try await request.response()

        guard let artist = response.items.first else { return nil }

        let detailedArtist = try await artist.with([.fullAlbums, .singles, .latestRelease])
        let fullAlbums = try await allBatches(of: detailedArtist.fullAlbums)
        let singles = try await allBatches(of: detailedArtist.singles)

        return artistData(
            from: detailedArtist,
            albums: fullAlbums.map { albumData(from: $0) },
            singles: singles.map { albumData(from: $0) },
            latestRelease: detailedArtist.latestRelease.map { albumData(from: $0) }
        )
    }

    public func fetchArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData? {
        var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(albumId))
        request.properties = [.artists]
        let response = try await request.response()

        guard let artist = response.items.first?.artists?.first else { return nil }

        return try await fetchArtistData(byId: artist.id.rawValue)
    }

    /// Collects an album relationship across its paginated batches, capped so
    /// huge discographies don't fan out into unbounded requests.
    private func allBatches(of collection: MusicItemCollection<Album>?) async throws -> [Album] {
        guard let collection else { return [] }

        var albums = Array(collection)
        var currentBatch = collection
        var batchCount = 1

        while currentBatch.hasNextBatch, batchCount < Constants.maxArtistAlbumBatches {
            guard let nextBatch = try await currentBatch.nextBatch() else { break }
            albums.append(contentsOf: nextBatch)
            currentBatch = nextBatch
            batchCount += 1
        }

        return albums
    }

    // MARK: - Catalog Search

    public func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] {
        guard !searchTerm.isEmpty else { return [] }

        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Album.self])
        request.limit = Constants.albumSearchLimit
        let response = try await request.response()

        return response.albums.map { albumData(from: $0) }
    }

    public func search(searchTerm: String) async throws -> MusicSearchResults {
        guard !searchTerm.isEmpty else { return .empty }

        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Album.self, Artist.self])
        request.limit = Constants.albumSearchLimit
        let response = try await request.response()

        return MusicSearchResults(
            albums: response.albums.map { albumData(from: $0) },
            artists: response.artists.map { artistData(from: $0) }
        )
    }

    // MARK: - Recently Played

    /// Returns the user's recently-played albums, most recent first.
    public func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData] {
        var request = MusicRecentlyPlayedContainerRequest()
        // Apple Music caps the recently-played limit at 10
        request.limit = Constants.albumRecentLimit
        let response = try await request.response()

        return response.items.compactMap { item in
            guard case let .album(album) = item else { return nil }
            return albumData(from: album)
        }
    }

    // MARK: - Album Mapping

    /// Maps a MusicKit catalog album to the app-facing model.
    private func albumData(from album: Album, tracks: [Models.Track]? = nil) -> AppleMusicAlbumData {
        AppleMusicAlbumData(
            id: album.id.rawValue,
            title: album.title,
            artist: album.artistName,
            coverUrl: album.artwork?.url(width: Constants.albumCoverSize, height: Constants.albumCoverSize),
            releaseDate: album.releaseDate,
            genre: album.genreNames.first,
            tracks: tracks,
            recordLabel: album.recordLabelName,
            copyright: album.copyright,
            appleMusicUrl: album.url
        )
    }

    // MARK: - Artist Mapping

    /// Maps a MusicKit catalog artist to the app-facing model.
    private func artistData(from artist: Artist,
                            albums: [AppleMusicAlbumData]? = nil,
                            singles: [AppleMusicAlbumData]? = nil,
                            latestRelease: AppleMusicAlbumData? = nil) -> AppleMusicArtistData {
        AppleMusicArtistData(
            id: artist.id.rawValue,
            name: artist.name,
            imageUrl: artist.artwork?.url(width: Constants.albumCoverSize, height: Constants.albumCoverSize),
            genres: artist.genreNames ?? [],
            appleMusicUrl: artist.url,
            albums: albums,
            singles: singles,
            latestRelease: latestRelease
        )
    }

    private enum Constants {
        static let albumCoverSize: Int = 300
        static let albumSearchLimit: Int = 20
        static let albumRecentLimit: Int = 10
        // Relationship batches hold 25 items, so four batches ≈ 100 albums per section.
        static let maxArtistAlbumBatches: Int = 4
        static let subscriptionTimeout: Duration = .seconds(2)
    }
}
