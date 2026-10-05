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
    /// The English name; the shown title is picked per language when read back.
    public var name: String
    /// Firebase's `name_pl`; `nil` for rows cached before it existed.
    public var namePL: String?
    public var order: Int
    public var orderedAlbumIds: [String]
    public var lastUpdated: Date

    @Relationship
    public var albums: [CachedAlbum]?

    public init(sectionId: String, name: String, namePL: String? = nil, order: Int, orderedAlbumIds: [String] = []) {
        self.sectionId = sectionId
        self.name = name
        self.namePL = namePL
        self.order = order
        self.orderedAlbumIds = orderedAlbumIds
        self.lastUpdated = Date()
    }
    
    @MainActor public func toHomeSection() -> HomeSection {
        guard let albums = albums, !albums.isEmpty else {
            return HomeSection(name: name, namePL: namePL, albums: [])
        }

        // Create a dictionary for fast lookup
        let albumDict = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })

        // Sort albums according to orderedAlbumIds
        let sortedAlbums = orderedAlbumIds.compactMap { albumId in
            albumDict[albumId].flatMap { $0.toAlbumModel() }
        }

        return HomeSection(name: name, namePL: namePL, albums: sortedAlbums)
    }
}
