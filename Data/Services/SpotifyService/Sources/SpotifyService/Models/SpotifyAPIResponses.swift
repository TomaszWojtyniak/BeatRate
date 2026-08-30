//
//  SpotifyAPIResponses.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

// Snake_case keys (`access_token`, ...) are handled by SpotifyNetworkClient's decoder.

nonisolated struct SpotifyTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: TimeInterval?

    /// Spotify access tokens are one hour unless told otherwise.
    static let defaultLifetime: TimeInterval = 3600

    func tokens(issuedAt: Date = Date()) -> SpotifyTokens {
        SpotifyTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: issuedAt.addingTimeInterval(expiresIn ?? Self.defaultLifetime)
        )
    }
}

nonisolated struct SpotifyUserResponse: Decodable, Sendable {
    let product: String?
}

nonisolated struct SpotifyRecentlyPlayedResponse: Decodable, Sendable {
    let items: [Item]

    struct Item: Decodable, Sendable {
        let track: Track
    }

    struct Track: Decodable, Sendable {
        let album: Album
    }

    struct Album: Decodable, Sendable {
        let id: String
        let name: String
        let artists: [Artist]
    }

    struct Artist: Decodable, Sendable {
        let name: String
    }
}

nonisolated extension SpotifyRecentlyPlayedResponse {
    /// Albums from the feed, deduplicated by id, in listening order.
    var uniqueAlbums: [SpotifyRecentAlbum] {
        var seenIds = Set<String>()
        var albums: [SpotifyRecentAlbum] = []
        for item in items {
            let album = item.track.album
            guard seenIds.insert(album.id).inserted else { continue }
            albums.append(
                SpotifyRecentAlbum(
                    id: album.id,
                    name: album.name,
                    artist: album.artists.first?.name ?? ""
                )
            )
        }
        return albums
    }
}
