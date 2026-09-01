//
//  SpotifyLink.swift
//  Models
//
//  Created by Tomasz Wojtyniak on 30/08/2026.
//

import Foundation

/// Builds Spotify links without the Web API.
///
/// Resolving an exact album id needs an authenticated search request, which in
/// Development Mode only succeeds for the handful of allowlisted accounts. A
/// search URL needs no token at all, so the link works for every user — it lands
/// on search results rather than the album page, which is the accepted trade.
public enum SpotifyLink {
    private static let searchBase = "https://open.spotify.com/search/"

    public static func search(title: String, artist: String) -> URL? {
        let query = "\(title) \(artist)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        let collapsed = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard let encoded = collapsed.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: " "))
        ) else { return nil }

        return URL(string: searchBase + encoded)
    }
}
