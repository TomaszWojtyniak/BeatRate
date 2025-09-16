//
//  CachedAlbum.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftData
import Foundation

@Model
public final class CachedAlbum {
    @Attribute(.unique) public var albumId: String
    public var title: String
    public var artist: String
    public var coverUrlString: String?
    public var releaseDate: Date?
    public var genre: String?
    public var rating: Double?
    public var lastUpdated: Date
    
    @Relationship(inverse: \CachedSection.albums)
    public var sections: [CachedSection]?
    
    public init(albumId: String, title: String, artist: String, coverUrlString: String? = nil, 
                releaseDate: Date? = nil, genre: String? = nil, rating: Double? = nil) {
        self.albumId = albumId
        self.title = title
        self.artist = artist
        self.coverUrlString = coverUrlString
        self.releaseDate = releaseDate
        self.genre = genre
        self.rating = rating
        self.lastUpdated = Date()
    }
    
    @MainActor public func toAlbumModel() -> AlbumModel {
        AlbumModel(
            title: title,
            artist: artist,
            coverUrl: coverUrlString.flatMap { URL(string: $0) },
            releaseDate: releaseDate,
            genre: genre,
            rating: rating
        )
    }
}
