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
    public let albums: [Album]
    
    public init(sectionName: String, albums: [Album]) {
        self.sectionName = sectionName
        self.albums = albums
    }
}
