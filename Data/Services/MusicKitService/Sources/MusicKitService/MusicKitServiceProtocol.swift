//
//  MusicKitServiceProtocol.swift
//  MusicKitService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

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
    func fetchArtistData(byId artistId: String) async throws -> AppleMusicArtistData?
    func fetchArtistData(forAlbumId albumId: String) async throws -> AppleMusicArtistData?
    func searchAlbums(searchTerm: String) async throws -> [AppleMusicAlbumData]
    func search(searchTerm: String) async throws -> MusicSearchResults
    func fetchRecentlyPlayedAlbums() async throws -> [AppleMusicAlbumData]
}
