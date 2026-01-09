//
//  AppleMusicAlbum.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 28/09/2025.
//

import SwiftUI

public struct AppleMusicAlbumData: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let coverUrl: URL?
    public let releaseDate: Date?
    public let genre: String?

    public init(id: String,
                title: String,
                artist: String,
                coverUrl: URL?,
                releaseDate: Date?,
                genre: String?) {
        self.id = id
        self.title = title
        self.artist = artist
        self.coverUrl = coverUrl
        self.releaseDate = releaseDate
        self.genre = genre
    }
}

extension AppleMusicAlbumData {
    public static var albumPlaceholder: Self {
        AppleMusicAlbumData(id: "1", title: "Name", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }
}
