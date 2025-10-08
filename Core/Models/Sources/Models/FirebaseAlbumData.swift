//
//  FirebaseAlbumData.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 07/10/2025.
//

import Foundation

public struct FirebaseAlbumData: Codable, Sendable {
    public let artist: String?
    public let avgRating: Double?
    public let createdAt: Int64?
    public let ratingCount: Int?
    public let title: String?

    public init(artist: String?,
                avgRating: Double?,
                createdAt: Int64?,
                ratingCount: Int?,
                title: String?) {
        self.artist = artist
        self.avgRating = avgRating
        self.createdAt = createdAt
        self.ratingCount = ratingCount
        self.title = title
    }
}
