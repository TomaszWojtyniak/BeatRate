//
//  AppleMusicAPI.swift
//  MusicKitService
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

/// Catalog of the raw Apple Music API endpoints and page limits the service
/// uses. Most requests go through MusicKit's typed layer; these exist only for
/// the calls that bypass it. Force-unwraps of known-valid URL literals live
/// only in this file.
nonisolated enum AppleMusicAPI {

    // MARK: - Endpoints

    private static let base = URL(string: "https://api.music.apple.com")!

    /// `albums/{id}/tracks` relationship endpoint, first page.
    static func albumTracks(storefront: String, albumId: String) -> URL {
        base.appending(path: "v1/catalog/\(storefront)/albums/\(albumId)/tracks")
            .appending(queryItems: [
                URLQueryItem(name: Param.limit, value: String(Limit.trackPage))
            ])
    }

    /// Pagination `next` values are server-relative paths ("/v1/catalog/...").
    static func nextPage(_ path: String) -> URL? {
        URL(string: path, relativeTo: base)
    }

    // MARK: - Query Parameter Names

    enum Param {
        static let limit = "limit"
    }

    // MARK: - Fixed Values

    enum Value {
        static let explicitRating = "explicit"
    }

    // MARK: - Page Limits

    enum Limit {
        /// Maximum the relationship endpoint accepts per page.
        static let trackPage = 300
    }
}
