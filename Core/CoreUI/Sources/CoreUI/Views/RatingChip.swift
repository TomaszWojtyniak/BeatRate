//
//  RatingChip.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 23/06/2026.
//

import SwiftUI

/// Liquid Glass capsule showing a rating (honey star + one-decimal score,
/// e.g. `★ 9.1`). Designed to be pinned to the top-trailing corner of album
/// artwork. Presentational only — no tap handling.
public struct RatingChip: View {

    /// Rating on the 0…10 scale (e.g. the current user's own album rating).
    let rating: Double

    public init(rating: Double) {
        self.rating = rating
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "star.fill")
                .textStyle(.iconChip, color: .accentPrimary)

            Text(rating, format: .number.precision(.fractionLength(1)))
                .textStyle(.captionValue, color: .primaryTextOnDark)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        // Liquid Glass handles its own translucency, edge highlight and inner
        // stroke. A fixed-dark tint keeps the white number and honey star legible
        // over light album covers.
        .glassEffect(.regular.tint(Color.glassTintOnMedia), in: Capsule())
    }
}

#Preview {
    RatingChip(rating: 9.1)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.albumPlaceholderColor)
}
