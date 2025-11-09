//
//  RecentAlbum.swift
//  Models
//
//  Created by Claude on 09/11/2025.
//

import SwiftData
import Foundation

@Model
public final class RecentAlbum {
    @Attribute(.unique) public var id: String

    @Attribute(.externalStorage) public var appleMusicAlbumDataData: Data

    public var addedAt: Date

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
                addedAt = Date()
            } catch {
                fatalError("Failed to encode AppleMusicAlbumData: \(error)")
            }
        }
    }

    public init(id: String, appleMusicAlbumDataData: Data) {
        self.id = id
        self.appleMusicAlbumDataData = appleMusicAlbumDataData
        self.addedAt = Date()
    }

    @MainActor
    public convenience init(id: String, appleMusicAlbumData: AppleMusicAlbumData) {
        do {
            let musicData = try JSONEncoder().encode(appleMusicAlbumData)
            self.init(id: id, appleMusicAlbumDataData: musicData)
        } catch {
            fatalError("Failed to encode album data for init: \(error)")
        }
    }

    @MainActor
    public func toAppleMusicAlbumData() -> AppleMusicAlbumData {
        return appleMusicAlbumData
    }
}
