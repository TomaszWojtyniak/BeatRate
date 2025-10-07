//
//  AlbumModel.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI

public struct AlbumModel: Identifiable, Hashable, Sendable {
    public var id: String
    public let appleMusicAlbumData: AppleMusicAlbumData
    public let firebaseAlbumData: FirebaseAlbumData?
    public let userRating: Double?

    public init(id: String, appleMusicAlbumData: AppleMusicAlbumData, firebaseAlbumData: FirebaseAlbumData?, userRating: Double? = nil) {
        self.id = id
        self.appleMusicAlbumData = appleMusicAlbumData
        self.firebaseAlbumData = firebaseAlbumData
        self.userRating = userRating
    }
    
    public static func == (lhs: AlbumModel, rhs: AlbumModel) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension AlbumModel {
    public static var albumPlaceholder: Self {
        AlbumModel(id: "1", appleMusicAlbumData: AppleMusicAlbumData(title: "Name", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil), firebaseAlbumData: nil)
    }
}
