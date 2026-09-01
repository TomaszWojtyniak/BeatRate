//
//  MusicRepository.swift
//  MusicRepository
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import OSLog
import Analytics
import CoreApp
import MusicKitService
import Models
import SpotifyService

struct AlbumNotFoundError: Error {
    let id: String

    var errorDescription: String? {
        return "Album with ID '\(id)' was not found"
    }
}

struct ArtistNotFoundError: Error {
    let id: String

    var errorDescription: String? {
        return "Artist for '\(id)' was not found"
    }
}

// MARK: - Authorization Info

public struct MusicAuthorizationInfo: Sendable {
    public let isAuthorized: Bool
    public let hasSubscription: Bool

    public init(isAuthorized: Bool, hasSubscription: Bool) {
        self.isAuthorized = isAuthorized
        self.hasSubscription = hasSubscription
    }
}

public struct SpotifyAuthorizationInfo: Sendable {
    public let isAuthorized: Bool
    public let premium: SpotifyPremiumStatus

    public init(isAuthorized: Bool, premium: SpotifyPremiumStatus) {
        self.isAuthorized = isAuthorized
        self.premium = premium
    }
}

// MARK: - Protocol

public protocol MusicRepositoryProtocol: Sendable {
    func requestMusicAuthorization() async -> MusicAuthorizationInfo
    func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo
    func fetchRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AppleMusicAlbumData]
    func hasStoredSpotifySession() async -> Bool
    func verifySpotifyConnection() async -> SpotifyConnectionState
    func isAppleMusicAuthorized() async -> Bool
    func isMusicKitAuthorizationDetermined() async -> Bool
    func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData
    func getArtistData(byId artistId: String) async throws -> AppleMusicArtistData
    func getArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData
    func search(searchTerm: String) async throws -> MusicSearchResults
}

// MARK: - MusicRepository

public actor MusicRepository: MusicRepositoryProtocol {
    public static let shared = MusicRepository()

    let musicKitService: MusicKitServiceProtocol
    let spotifyService: SpotifyServiceProtocol

    private var isMusicKitAuthorized: Bool = false
    private var cachedHasSubscription: Bool = false

    public init(
        musicKitService: MusicKitServiceProtocol = MusicKitService.shared,
        spotifyService: SpotifyServiceProtocol = SpotifyService.shared
    ) {
        self.musicKitService = musicKitService
        self.spotifyService = spotifyService
    }

    // MARK: - Apple Music

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

    public func getArtistData(byId artistId: String) async throws -> AppleMusicArtistData {
        Logger.musicRepository.info("Fetching artist with ID: '\(artistId)'")

        guard let artist = try await musicKitService.fetchArtistData(byId: artistId) else {
            throw ArtistNotFoundError(id: artistId)
        }
        return artist
    }

    public func getArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData {
        Logger.musicRepository.info("Fetching artist for album: '\(albumId)'")

        guard let artist = try await musicKitService.fetchArtistData(forAlbumId: albumId) else {
            throw ArtistNotFoundError(id: albumId)
        }
        return artist
    }

    public func search(searchTerm: String) async throws -> MusicSearchResults {
        Logger.musicRepository.info("Searching catalog with query: '\(searchTerm)'")

        let results = try await musicKitService.search(searchTerm: searchTerm)
        Logger.musicRepository.info("Found \(results.albums.count) albums and \(results.artists.count) artists for query: '\(searchTerm)'")
        return results
    }

    // MARK: - Spotify

    public func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo {
        Logger.musicRepository.info("Requesting Spotify authorization")

        let result = try await spotifyService.requestAuthorization()

        return await SpotifyAuthorizationInfo(
            isAuthorized: result.isAuthorized,
            premium: result.premium
        )
    }

    // MARK: - Recently Listened

    public func fetchRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AppleMusicAlbumData] {
        switch player {
        case .appleMusic:
            return try await musicKitService.fetchRecentlyPlayedAlbums()
        case .spotify:
            let spotifyAlbums = try await spotifyService.fetchRecentlyPlayedAlbums()
            return await matchSpotifyAlbumsToAppleMusic(spotifyAlbums)
        }
    }

    /// Apple throttles bursts of catalog requests, so cap how many of the up to
    /// 50 recently-played lookups run at once.
    private nonisolated static let maxConcurrentCatalogSearches = 5

    /// Looks up each Spotify-played album in the Apple Music catalog by title + artist,
    /// returning the matched Apple Music albums. Search results are loosely ranked,
    /// so each one is verified against the Spotify artist and album name.
    private func matchSpotifyAlbumsToAppleMusic(_ spotifyAlbums: [SpotifyRecentAlbum]) async -> [AppleMusicAlbumData] {
        await spotifyAlbums.concurrentCompactMap(maxConcurrent: Self.maxConcurrentCatalogSearches) { spotifyAlbum in
            let searchTerm = "\(spotifyAlbum.name) \(spotifyAlbum.artist)"
                .trimmingCharacters(in: .whitespaces)
            let matches = (try? await self.musicKitService.searchAlbums(searchTerm: searchTerm)) ?? []
            guard let match = SpotifyAlbumMatcher.bestMatch(for: spotifyAlbum, in: matches) else {
                Logger.musicRepository.debug("No verified Apple Music match for '\(spotifyAlbum.name)' by '\(spotifyAlbum.artist)'")
                return nil
            }
            return match
        }
    }

    public func hasStoredSpotifySession() async -> Bool {
        await spotifyService.hasStoredSession()
    }

    public func verifySpotifyConnection() async -> SpotifyConnectionState {
        await spotifyService.verifyConnection()
    }

    public func isAppleMusicAuthorized() async -> Bool {
        await musicKitService.isAuthorized()
    }

    public func isMusicKitAuthorizationDetermined() async -> Bool {
        await musicKitService.isAuthorizationDetermined()
    }
}
