//
//  CachedAlbum.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftData
import OSLog
import Foundation

@Model
public final class CachedAlbum {
    @Attribute(.unique) public var id: String

    @Attribute(.externalStorage) public var appleMusicAlbumDataData: Data
    @Attribute(.externalStorage) public var firebaseAlbumDataData: Data?

    public var userRating: Double?
    public var userRatingUpdatedAt: Date?

    /// Nil rather than a trap when the stored blob will not decode. The cache is
    /// derived data, so a row written by an older schema has to read as a miss —
    /// crashing here would brick the app on the first release that changes shape.
    @MainActor
    public var appleMusicAlbumData: AppleMusicAlbumData? {
        get {
            do {
                return try JSONDecoder().decode(AppleMusicAlbumData.self, from: appleMusicAlbumDataData)
            } catch {
                Self.log.error("Discarding undecodable AppleMusicAlbumData for \(self.id): \(error)")
                return nil
            }
        }
        set {
            guard let newValue, let encoded = try? JSONEncoder().encode(newValue) else {
                Self.log.error("Failed to encode AppleMusicAlbumData for \(self.id)")
                return
            }
            appleMusicAlbumDataData = encoded
            lastUpdated = Date()
        }
    }

    @MainActor
    public var firebaseAlbumData: FirebaseAlbumData? {
        get {
            guard let data = firebaseAlbumDataData else { return nil }
            do {
                return try JSONDecoder().decode(FirebaseAlbumData.self, from: data)
            } catch {
                Self.log.error("Discarding undecodable FirebaseAlbumData for \(self.id): \(error)")
                return nil
            }
        }
        set {
            guard let newValue else {
                firebaseAlbumDataData = nil
                lastUpdated = Date()
                return
            }
            guard let encoded = try? JSONEncoder().encode(newValue) else {
                Self.log.error("Failed to encode FirebaseAlbumData for \(self.id)")
                return
            }
            firebaseAlbumDataData = encoded
            lastUpdated = Date()
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

    /// Failable: an album that will not encode simply does not get cached.
    @MainActor
    public convenience init?(id: String, appleMusicAlbumData: AppleMusicAlbumData, firebaseAlbumData: FirebaseAlbumData? = nil) {
        do {
            let musicData = try JSONEncoder().encode(appleMusicAlbumData)
            let firebaseData = firebaseAlbumData != nil ? try JSONEncoder().encode(firebaseAlbumData) : nil
            self.init(id: id, appleMusicAlbumDataData: musicData, firebaseAlbumDataData: firebaseData)
        } catch {
            Self.log.error("Not caching album \(id), encode failed: \(error)")
            return nil
        }
    }

    /// Nil when the Apple Music blob is unreadable — callers treat that as a miss.
    @MainActor public func toAlbumModel() -> AlbumModel? {
        guard let appleMusicAlbumData else { return nil }
        return AlbumModel(
            id: id,
            appleMusicAlbumData: appleMusicAlbumData,
            firebaseAlbumData: firebaseAlbumData,
            userRating: userRating
        )
    }

    fileprivate static let log = Logger(subsystem: "BeatRate", category: "modelCache")
}
