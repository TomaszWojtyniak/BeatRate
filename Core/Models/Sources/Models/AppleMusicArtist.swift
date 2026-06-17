//
//  AppleMusicArtist.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 11/06/2026.
//

import SwiftUI

public struct AppleMusicArtistData: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let imageUrl: URL?
    public let genres: [String]
    public let appleMusicUrl: URL?
    // nil when coming from search results; populated by the artist detail fetch
    public let albums: [AppleMusicAlbumData]?
    public let singles: [AppleMusicAlbumData]?
    public let latestRelease: AppleMusicAlbumData?

    public init(id: String,
                name: String,
                imageUrl: URL?,
                genres: [String],
                appleMusicUrl: URL? = nil,
                albums: [AppleMusicAlbumData]? = nil,
                singles: [AppleMusicAlbumData]? = nil,
                latestRelease: AppleMusicAlbumData? = nil) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
        self.genres = genres
        self.appleMusicUrl = appleMusicUrl
        self.albums = albums
        self.singles = singles
        self.latestRelease = latestRelease
    }
}

extension AppleMusicArtistData {
    public static var artistPlaceholder: Self {
        AppleMusicArtistData(
            id: "1",
            name: "Artist",
            imageUrl: nil,
            genres: ["Pop"],
            albums: [.albumPlaceholder],
            singles: [.albumPlaceholder],
            latestRelease: .albumPlaceholder
        )
    }
}
