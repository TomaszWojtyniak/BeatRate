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
import SpotifyService

struct AlbumNotFoundError: Error {
    let id: String

    var errorDescription: String? {
        return "Album with ID '\(id)' was not found"
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
    public let hasSpotifyPremium: Bool

    public init(isAuthorized: Bool, hasSpotifyPremium: Bool) {
        self.isAuthorized = isAuthorized
        self.hasSpotifyPremium = hasSpotifyPremium
    }
}

// MARK: - Protocol

public protocol MusicRepositoryProtocol: Sendable {
    func requestMusicAuthorization() async -> MusicAuthorizationInfo
    func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo
    func fetchSpotifyRecentlyPlayed() async throws
    func fetchRecentlyListenedAlbums(for player: MusicPlayer) async throws -> [AppleMusicAlbumData]
    func isSpotifyTokenAvailable() async -> Bool
    func verifySpotifyConnection() async -> SpotifyConnectionState
    func isAppleMusicAuthorized() async -> Bool
    func isMusicKitAuthorizationDetermined() async -> Bool
    func getAlbumDataById(_ id: String) async throws -> AppleMusicAlbumData
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
    func searchSpotifyAlbumId(name: String, artist: String) async -> String?
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

    public func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData] {
        Logger.musicRepository.info("Searching albums with query: '\(searchTerm)'")

        let albums = try await musicKitService.searchAlbums(searchTerm: searchTerm)
        Logger.musicRepository.info("Found \(albums.count) albums for query: '\(searchTerm)'")
        return albums
    }

    // MARK: - Spotify

    public func requestSpotifyAuthorization() async throws -> SpotifyAuthorizationInfo {
        Logger.musicRepository.info("Requesting Spotify authorization")

        let result = try await spotifyService.requestAuthorization()

        return await SpotifyAuthorizationInfo(
            isAuthorized: result.isAuthorized,
            hasSpotifyPremium: result.hasSpotifyPremium
        )
    }

    public func fetchSpotifyRecentlyPlayed() async throws {
        try await spotifyService.fetchRecentlyPlayed()
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

    /// Looks up each Spotify-played album in the Apple Music catalog by title + artist,
    /// returning the matched Apple Music albums. Search results are loosely ranked,
    /// so each one is verified against the Spotify artist and album name.
    private func matchSpotifyAlbumsToAppleMusic(_ spotifyAlbums: [SpotifyRecentAlbum]) async -> [AppleMusicAlbumData] {
        await withTaskGroup(of: (order: Int, album: AppleMusicAlbumData?).self) { group in
            for (index, spotifyAlbum) in spotifyAlbums.enumerated() {
                group.addTask {
                    let searchTerm = "\(spotifyAlbum.name) \(spotifyAlbum.artist)"
                        .trimmingCharacters(in: .whitespaces)
                    let matches = (try? await self.musicKitService.searchAlbums(searchTerm: searchTerm)) ?? []
                    guard let match = SpotifyAlbumMatcher.bestMatch(for: spotifyAlbum, in: matches) else {
                        Logger.musicRepository.debug("No verified Apple Music match for '\(spotifyAlbum.name)' by '\(spotifyAlbum.artist)'")
                        return (order: index, album: nil)
                    }
                    return (order: index, album: match)
                }
            }

            var results: [(order: Int, album: AppleMusicAlbumData?)] = []
            for await result in group {
                results.append(result)
            }

            return results
                .sorted { $0.order < $1.order }
                .compactMap { $0.album }
        }
    }

    public func isSpotifyTokenAvailable() async -> Bool {
        await spotifyService.hasAccessToken()
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

    public func searchSpotifyAlbumId(name: String, artist: String) async -> String? {
        await spotifyService.searchAlbumId(name: name, artist: artist)
    }
}
