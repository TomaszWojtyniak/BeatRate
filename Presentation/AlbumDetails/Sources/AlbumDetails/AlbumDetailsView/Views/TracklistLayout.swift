//
//  TracklistLayout.swift
//  AlbumDetails
//

import Foundation
import Models

/// What the tracklist card shows: tracks in release order, collapsed to the
/// first few until expanded, grouped by disc when the album has more than one.
struct TracklistLayout {
    /// Number of tracks shown when collapsed.
    static let collapsedLimit = 5

    let tracks: [Track]
    let isExpanded: Bool

    var sortedTracks: [Track] {
        tracks.sorted {
            let lhs = ($0.discNumber ?? 1, $0.trackNumber ?? 0)
            let rhs = ($1.discNumber ?? 1, $1.trackNumber ?? 0)
            return lhs < rhs
        }
    }

    var canCollapse: Bool {
        tracks.count > Self.collapsedLimit
    }

    var visibleTracks: [Track] {
        guard canCollapse, !isExpanded else { return sortedTracks }
        return Array(sortedTracks.prefix(Self.collapsedLimit))
    }

    var showsDiscHeaders: Bool {
        Set(tracks.map { $0.discNumber ?? 1 }).count > 1
    }

    var groupedVisible: [(disc: Int, tracks: [Track])] {
        Dictionary(grouping: visibleTracks, by: { $0.discNumber ?? 1 })
            .map { (disc: $0.key, tracks: $0.value) }
            .sorted { $0.disc < $1.disc }
    }

    /// `m:ss`, rounded to the nearest second.
    static func duration(_ duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
