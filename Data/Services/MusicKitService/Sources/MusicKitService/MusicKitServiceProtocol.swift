//
//  MusicKitServiceProtocol.swift
//  MusicKitService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Models

/// Apple Music access as the app sees it, so nothing above the service needs MusicKit.
nonisolated public enum MusicAccessStatus: Sendable {
    case notDetermined, denied, restricted, authorized
}

public struct MusicAuthorizationResult: Sendable {
    public let status: MusicAccessStatus
    public let hasSubscription: Bool

    public init(status: MusicAccessStatus, hasSubscription: Bool) {
        self.status = status
        self.hasSubscription = hasSubscription
    }
}

/// Nonisolated so the MusicKit actor in MusicKitServiceLive can conform from another module.
nonisolated public protocol MusicKitServiceProtocol: Sendable {
    func requestMusicAuthorization() async -> MusicAuthorizationResult
    func isAuthorized() async -> Bool
    func isAuthorizationDetermined() async -> Bool
    func fetchAlbumData(by id: String) async throws -> AppleMusicAlbumData?
    func fetchArtistData(byId artistId: String) async throws -> AppleMusicArtistData?
    func fetchArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData?
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
    func search(searchTerm: String) async throws -> MusicSearchResults
    func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData]
}
