//
//  AlbumModel.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI

public struct AlbumModel: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let artist: String
    public let cover: String
    
    public init(title: String, artist: String, cover: String) {
        self.title = title
        self.artist = artist
        self.cover = cover
    }
}
