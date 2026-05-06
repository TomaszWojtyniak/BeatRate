//
//  AlbumTracklistView.swift
//  AlbumDetails
//

import SwiftUI
import Models
import CoreUI

struct AlbumTracklistView: View {
    let tracks: [Track]

    /// Number of tracks shown when collapsed.
    private static let collapsedLimit = 5

    @State private var isExpanded = false

    private var sortedTracks: [Track] {
        tracks.sorted {
            let lhs = ($0.discNumber ?? 1, $0.trackNumber ?? 0)
            let rhs = ($1.discNumber ?? 1, $1.trackNumber ?? 0)
            return lhs < rhs
        }
    }

    private var canCollapse: Bool {
        tracks.count > Self.collapsedLimit
    }

    private var visibleTracks: [Track] {
        guard canCollapse, !isExpanded else { return sortedTracks }
        return Array(sortedTracks.prefix(Self.collapsedLimit))
    }

    private var showsDiscHeaders: Bool {
        Set(tracks.map { $0.discNumber ?? 1 }).count > 1
    }

    private var groupedVisible: [(disc: Int, tracks: [Track])] {
        Dictionary(grouping: visibleTracks, by: { $0.discNumber ?? 1 })
            .map { (disc: $0.key, tracks: $0.value) }
            .sorted { $0.disc < $1.disc }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            card
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Text("Tracks")
                .textStyle(.titleSection)
            Spacer()
            Text("\(tracks.count)")
                .textStyle(.caption, color: .secondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var card: some View {
        VStack(spacing: 0) {
            TracklistContent(
                groups: groupedVisible,
                showsDiscHeaders: showsDiscHeaders
            )

            if canCollapse {
                Divider().padding(.leading, Spacing.md)
                toggleButton
            }
        }
        .padding(.vertical, Spacing.xs)
        .roundedMaterialBackground()
    }

    private var toggleButton: some View {
        Button {
            withAnimation(AppAnimation.smooth) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(isExpanded ? "Show less" : "Show all")
                    .textStyle(.bodyEmphasis, color: .accentPrimary)
                    .fixedSize()
                    .frame(width: Size.trackNumberColumn, alignment: .leading)

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.down")
                    .textStyle(.iconRowAccessory, color: .accentPrimary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TracklistContent: View {
    let groups: [(disc: Int, tracks: [Track])]
    let showsDiscHeaders: Bool

    var body: some View {
        ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, group in
            if showsDiscHeaders {
                if groupIndex > 0 {
                    Divider().padding(.vertical, Spacing.xs)
                }
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "opticaldisc")
                        .textStyle(.iconChip, color: .secondaryText)
                    Text("Disc \(group.disc)")
                        .textStyle(.label, foreground: .tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
            }

            ForEach(Array(group.tracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track)
                if index < group.tracks.count - 1 {
                    Divider().padding(.leading, Spacing.md)
                }
            }
        }
    }
}

private struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Text(numberText)
                .textStyle(.caption, color: .secondaryText)
                .monospacedDigit()
                .frame(width: Size.trackNumberColumn, alignment: .leading)

            Text(track.title)
                .textStyle(.bodyEmphasis)
                .lineLimit(2)

            if track.isExplicit {
                Image(systemName: "e.square.fill")
                    .textStyle(.iconChip, color: .secondaryText)
                    .accessibilityLabel("Explicit")
            }

            Spacer(minLength: Spacing.xs)

            if let duration = track.duration {
                Text(format(duration))
                    .textStyle(.caption, color: .secondaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private var numberText: String {
        track.trackNumber.map(String.init) ?? "·"
    }

    private func format(_ duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let tracks: [Track] = (1...12).map { i in
        Track(id: "\(i)", title: "Track \(i)", trackNumber: i, discNumber: 1, duration: 200 + Double(i * 10), isExplicit: i % 3 == 0)
    }
    ScrollView {
        AlbumTracklistView(tracks: tracks)
            .padding(Spacing.lg)
    }
    .meshBackground()
}
