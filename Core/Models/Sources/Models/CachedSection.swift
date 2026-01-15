//
//  CachedSection.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftData
import Foundation

@Model
public final class CachedSection {
    @Attribute(.unique) public var sectionId: String
    public var name: String
    public var order: Int
    public var orderedAlbumIds: [String]
    public var lastUpdated: Date

    @Relationship
    public var albums: [CachedAlbum]?

    public init(sectionId: String, name: String, order: Int, orderedAlbumIds: [String] = []) {
        self.sectionId = sectionId
        self.name = name
        self.order = order
        self.orderedAlbumIds = orderedAlbumIds
        self.lastUpdated = Date()
    }
    
    @MainActor public func toHomeSection() -> HomeSection {
        guard let albums = albums, !albums.isEmpty else {
            return HomeSection(sectionName: name, albums: [])
        }

        // Create a dictionary for fast lookup
        let albumDict = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })

        // Sort albums according to orderedAlbumIds
        let sortedAlbums = orderedAlbumIds.compactMap { albumId in
            albumDict[albumId]?.toAlbumModel()
        }

        return HomeSection(sectionName: name, albums: sortedAlbums)
    }
}
