//
//  SpotifyRecentAlbum.swift
//  SpotifyService
//
//  Created by Tomasz Wojtyniak on 08/06/2026.
//

import Foundation

/// A single album pulled from Spotify's recently-played feed. 
public nonisolated struct SpotifyRecentAlbum: Sendable, Hashable {
    public let id: String
    public let name: String
    public let artist: String

    public init(id: String, name: String, artist: String) {
        self.id = id
        self.name = name
        self.artist = artist
    }
}
