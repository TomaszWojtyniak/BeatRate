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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Image("AppYellowLogomark")
                    .resizable()
                    .frame(width: Size.touchTarget, height: Size.touchTarget)
                    .appShadow(.accentGlow)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(myRating == 0 ? "Rate this album" : "Your rating")
                        .textStyle(.bodyEmphasis)

                    Text(myRating == 0
                         ? "Tap or drag a star to rate"
                         : "Double-tap a star for a half rating")
                        .textStyle(.caption)
                }

                Spacer(minLength: 0)

                if myRating > 0 {
                    Text(String(format: "%.1f", myRating))
                        .textStyle(.statValueCompact, color: .accentPrimary)
                        .contentTransition(.numericText(value: myRating))
                }
            }

            StarRatingView(rating: $myRating, onRatingFinalized: { final in
                onRatingFinalized?(final)
                withAnimation(AppAnimation.quick) {
                    showSavedFlash = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation(AppAnimation.standard) {
                        showSavedFlash = false
                    }
                }
            })
            .padding(.vertical, Spacing.xxs)

            if showSavedFlash {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentPrimary)
                    Text("Saved to your library")
                        .textStyle(.captionEmphasis)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.lg)
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
