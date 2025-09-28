//
//  AppleMusicAlbum.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 28/09/2025.
//

import SwiftUI

public struct AppleMusicAlbumData: Codable {
    public let title: String
    public let artist: String
    public let coverUrl: URL?
    public let releaseDate: Date?
    public let genre: String?
    
    public init(title: String,
                artist: String,
                coverUrl: URL?,
                releaseDate: Date?,
                genre: String?) {
        self.title = title
        self.artist = artist
        self.coverUrl = coverUrl
        self.releaseDate = releaseDate
        self.genre = genre
    }
}
