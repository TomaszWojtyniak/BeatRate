//
//  MusicSearchResults.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 11/06/2026.
//

import Foundation

/// Combined catalog search results for albums and artists.
public struct MusicSearchResults: Hashable, Sendable {
    public let albums: [AppleMusicAlbumData]
    public let artists: [AppleMusicArtistData]

    public init(albums: [AppleMusicAlbumData], artists: [AppleMusicArtistData]) {
        self.albums = albums
        self.artists = artists
    }

    public static var empty: Self {
        MusicSearchResults(albums: [], artists: [])
    }
}
