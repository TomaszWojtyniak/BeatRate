//
//  RateAlbumView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 02/08/2025.
//

import SwiftUI
import CoreUI

struct RateAlbumView: View {

    @Binding var myRating: Double
    var onRatingFinalized: ((Double) -> Void)?

    @State private var showSavedFlash: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                // Gradient star chip
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentPrimaryGradient)
                        .frame(width: 44, height: 44)
                        .appShadow(.accentGlow)

                    Image(systemName: "star.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(myRating == 0 ? "Rate this album" : "Your rating")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.primaryText)

                    Text(myRating == 0
                         ? "Tap or drag a star to rate"
                         : "Double-tap a star for a half rating")
                        .font(.system(.caption))
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer(minLength: 0)

                if myRating > 0 {
                    Text(String(format: "%.1f", myRating))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentPrimary)
                        .contentTransition(.numericText(value: myRating))
                }
            }

            StarRatingView(rating: $myRating, onRatingFinalized: { final in
                onRatingFinalized?(final)
                withAnimation(.easeOut(duration: 0.2)) {
                    showSavedFlash = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    withAnimation(.easeIn(duration: 0.25)) {
                        showSavedFlash = false
                    }
                }
            })
            .padding(.vertical, 4)

            if showSavedFlash {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentPrimary)
                    Text("Saved to your library")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .roundedMaterialBackground()
    }
}

#Preview {
    VStack {
        RateAlbumView(myRating: .constant(8.5))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.backgroundColor)
}
