//
//  FirebaseAlbumSection.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 29/07/2025.
//

import SwiftUI

public struct FirebaseAlbumSection: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    /// Optional Polish title, `name_pl` in Firebase.
    public let namePL: String?
    public let albums: [String]
    public let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, albums, isActive
        case namePL = "name_pl"
    }

    public init(id: String, name: String, namePL: String? = nil, albums: [String], isActive: Bool) {
        self.id = id
        self.name = name
        self.namePL = namePL
        self.albums = albums
        self.isActive = isActive
    }
}
