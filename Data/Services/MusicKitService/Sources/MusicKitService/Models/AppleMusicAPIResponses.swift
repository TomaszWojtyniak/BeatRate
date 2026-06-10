//
//  AppleMusicAPIResponses.swift
//  MusicKitService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation
import Models

/// Minimal shape of one page of the Apple Music API `albums/{id}/tracks` payload.
nonisolated struct AppleMusicTracksPage: Decodable, Sendable {
    let data: [Resource]
    let next: String?

    struct Resource: Decodable, Sendable {
        let id: String
        let attributes: Attributes

        struct Attributes: Decodable, Sendable {
            let name: String
            let trackNumber: Int?
            let discNumber: Int?
            let durationInMillis: Int?
            let contentRating: String?
        }
    }
}

nonisolated extension AppleMusicTracksPage {
    /// Tracks on this page, in release order, mapped to the app model.
    var tracks: [Track] {
        data.map { resource in
            Track(
                id: resource.id,
                title: resource.attributes.name,
                trackNumber: resource.attributes.trackNumber,
                discNumber: resource.attributes.discNumber,
                duration: resource.attributes.durationInMillis.map { TimeInterval($0) / 1000 },
                isExplicit: resource.attributes.contentRating == AppleMusicAPI.Value.explicitRating
            )
        }
    }
}
