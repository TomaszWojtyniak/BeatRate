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
    public let coverUrl: URL?
    
    public init(title: String, artist: String, coverUrl: URL?) {
        self.title = title
        self.artist = artist
        self.coverUrl = coverUrl
    }
}
