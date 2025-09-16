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
    public var lastUpdated: Date
    
    @Relationship
    public var albums: [CachedAlbum]?
    
    public init(sectionId: String, name: String, order: Int) {
        self.sectionId = sectionId
        self.name = name
        self.order = order
        self.lastUpdated = Date()
    }
    
    @MainActor public func toHomeSection() -> HomeSection {
        HomeSection(
            sectionName: name,
            albums: albums?.map { $0.toAlbumModel() } ?? []
        )
    }
}
