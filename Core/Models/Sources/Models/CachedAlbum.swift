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
    @Attribute(.externalStorage) public var firebaseAlbumDataData: Data?

    public var userRating: Double?
    public var userRatingUpdatedAt: Date?

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

    @MainActor
    public var firebaseAlbumData: FirebaseAlbumData? {
        get {
            guard let data = firebaseAlbumDataData else { return nil }
            do {
                return try JSONDecoder().decode(FirebaseAlbumData.self, from: data)
            } catch {
                fatalError("Failed to decode FirebaseAlbumData: \(error)")
            }
        }
        set {
            do {
                firebaseAlbumDataData = newValue != nil ? try JSONEncoder().encode(newValue) : nil
                lastUpdated = Date()
            } catch {
                fatalError("Failed to encode FirebaseAlbumData: \(error)")
            }
        }
    }

    public var lastUpdated: Date

    @Relationship(inverse: \CachedSection.albums)
    public var sections: [CachedSection]?

    public init(id: String, appleMusicAlbumDataData: Data, firebaseAlbumDataData: Data? = nil) {
        self.id = id
        self.appleMusicAlbumDataData = appleMusicAlbumDataData
        self.firebaseAlbumDataData = firebaseAlbumDataData
        self.lastUpdated = Date()
    }

    @MainActor
    public convenience init(id: String, appleMusicAlbumData: AppleMusicAlbumData, firebaseAlbumData: FirebaseAlbumData? = nil) {
        do {
            let musicData = try JSONEncoder().encode(appleMusicAlbumData)
            let firebaseData = firebaseAlbumData != nil ? try JSONEncoder().encode(firebaseAlbumData) : nil
            self.init(id: id, appleMusicAlbumDataData: musicData, firebaseAlbumDataData: firebaseData)
        } catch {
            fatalError("Failed to encode album data for init: \(error)")
        }
    }

    @MainActor public func toAlbumModel() -> AlbumModel {
        AlbumModel(
            id: id,
            appleMusicAlbumData: appleMusicAlbumData,
            firebaseAlbumData: firebaseAlbumData,
            userRating: userRating
        )
    }
}
