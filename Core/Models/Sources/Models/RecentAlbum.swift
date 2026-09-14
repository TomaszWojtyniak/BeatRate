//
//  RecentAlbum.swift
//  Models
//
//  Created by Claude on 09/11/2025.
//

import SwiftData
import OSLog
import Foundation

@Model
public final class RecentAlbum {
    @Attribute(.unique) public var id: String

    @Attribute(.externalStorage) public var appleMusicAlbumDataData: Data

    public var addedAt: Date

    /// Nil rather than a trap on an unreadable blob — see `CachedAlbum`.
    @MainActor
    public var appleMusicAlbumData: AppleMusicAlbumData? {
        get {
            do {
                return try JSONDecoder().decode(AppleMusicAlbumData.self, from: appleMusicAlbumDataData)
            } catch {
                Self.log.error("Discarding undecodable recent album \(self.id): \(error)")
                return nil
            }
        }
        set {
            guard let newValue, let encoded = try? JSONEncoder().encode(newValue) else {
                Self.log.error("Failed to encode recent album \(self.id)")
                return
            }
            appleMusicAlbumDataData = encoded
            addedAt = Date()
        }
    }

    public init(id: String, appleMusicAlbumDataData: Data) {
        self.id = id
        self.appleMusicAlbumDataData = appleMusicAlbumDataData
        self.addedAt = Date()
    }

    @MainActor
    public convenience init?(id: String, appleMusicAlbumData: AppleMusicAlbumData) {
        do {
            let musicData = try JSONEncoder().encode(appleMusicAlbumData)
            self.init(id: id, appleMusicAlbumDataData: musicData)
        } catch {
            Self.log.error("Not saving recent album \(id), encode failed: \(error)")
            return nil
        }
    }

    @MainActor
    public func toAppleMusicAlbumData() -> AppleMusicAlbumData? {
        return appleMusicAlbumData
    }

    fileprivate static let log = Logger(subsystem: "BeatRate", category: "modelCache")
}
