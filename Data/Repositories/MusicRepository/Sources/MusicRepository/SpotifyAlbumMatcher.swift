//
//  SpotifyAlbumMatcher.swift
//  MusicRepository
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation
import Models
import SpotifyService

/// Picks the Apple Music search result that actually corresponds to a Spotify
/// album. Catalog search returns up to 20 loosely ranked results, so the first
/// one is not necessarily the right record — verify artist and title instead.
nonisolated enum SpotifyAlbumMatcher {

    static func bestMatch(
        for spotifyAlbum: SpotifyRecentAlbum,
        in candidates: [AppleMusicAlbumData]
    ) -> AppleMusicAlbumData? {
        let targetTitle = words(of: spotifyAlbum.name)
        let targetArtist = normalize(spotifyAlbum.artist)
        guard !targetTitle.isEmpty else { return nil }

        let sameArtist = candidates.filter { matchesArtist($0.artist, target: targetArtist) }

        if let exact = sameArtist.first(where: { words(of: $0.title) == targetTitle }) {
            return exact
        }

        // Edition suffixes — "Title (Deluxe)", "Title - Remastered" — extend the
        // base title on either side, so accept a whole-word prefix relation.
        return sameArtist.first { candidate in
            let title = words(of: candidate.title)
            return title.starts(with: targetTitle) || targetTitle.starts(with: title)
        }
    }

    /// Apple often lists collaborations as "A & B" or "A feat. B" where Spotify
    /// reports only the primary artist, so containment counts as a match.
    private static func matchesArtist(_ candidate: String, target: String) -> Bool {
        guard !target.isEmpty else { return true }
        let candidate = normalize(candidate)
        return candidate == target
            || candidate.contains(target)
            || target.contains(candidate)
    }

    /// Case- and diacritic-folded, punctuation-free, whitespace-normalized.
    static func normalize(_ value: String) -> String {
        words(of: value).joined(separator: " ")
    }

    private static func words(of value: String) -> [String] {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
}
