//
//  HomeSection.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI

public struct HomeSection: Identifiable {
    public let id = UUID()
    public let sectionName: String
    public let albums: [AlbumModel]
    
    public init(sectionName: String, albums: [AlbumModel]) {
        self.sectionName = sectionName
        self.albums = albums
    }
}
