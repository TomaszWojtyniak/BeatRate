//
//  SpotifyAlbumData.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 04/03/2026.
//

import Foundation

public struct SpotifyAlbumData: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let coverUrl: URL?
    public let releaseDate: Date?
    public let genre: String?
    public let spotifyUri: String  // e.g. "spotify:album:xyz"
    
    public init(id: String, title: String, artist: String, coverUrl: URL?, releaseDate: Date?, genre: String?, spotifyUri: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.coverUrl = coverUrl
        self.releaseDate = releaseDate
        self.genre = genre
        self.spotifyUri = spotifyUri
    }
}
