//
//  AlbumModel.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI

public struct AlbumModel: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let artist: String
    public let coverUrl: URL?
    public let releaseDate: Date?
    public let genre: String?
    public let rating: Double?
    
    
    public init(title: String, artist: String, coverUrl: URL?, releaseDate: Date?, genre: String?, rating: Double? = nil) {
        self.title = title
        self.artist = artist
        self.coverUrl = coverUrl
        self.releaseDate = releaseDate
        self.genre = genre
        self.rating = rating
    }
}
