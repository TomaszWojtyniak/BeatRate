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
    @Attribute(.unique) public var id: String

    @Attribute(.externalStorage) public var appleMusicAlbumDataData: Data

    @MainActor
    public var appleMusicAlbumData: AppleMusicAlbumData {
        get {
            do {
                return try JSONDecoder().decode(AppleMusicAlbumData.self, from: appleMusicAlbumDataData)
            } catch {
                fatalError("Failed to decode AppleMusicAlbumData: \(error)")
            }
        }
        set {
            do {
                appleMusicAlbumDataData = try JSONEncoder().encode(newValue)
                lastUpdated = Date()
            } catch {
                fatalError("Failed to encode AppleMusicAlbumData: \(error)")
            }
        }
    }
    
    public var rating: Double?
    public var lastUpdated: Date
    
    @Relationship(inverse: \CachedSection.albums)
    public var sections: [CachedSection]?
    
    public init(id: String, appleMusicAlbumDataData: Data, rating: Double? = nil) {
        self.id = id
        self.appleMusicAlbumDataData = appleMusicAlbumDataData
        self.rating = rating
        self.lastUpdated = Date()
    }

    @MainActor
    public convenience init(id: String, appleMusicAlbumData: AppleMusicAlbumData, rating: Double? = nil) {
        do {
            let data = try JSONEncoder().encode(appleMusicAlbumData)
            self.init(id: id, appleMusicAlbumDataData: data, rating: rating)
        } catch {
            fatalError("Failed to encode AppleMusicAlbumData for init: \(error)")
        }
    }
    
    @MainActor public func toAlbumModel() -> AlbumModel {
        AlbumModel(
            id: id,
            appleMusicAlbumData: appleMusicAlbumData,
            rating: rating
        )
    }
}
