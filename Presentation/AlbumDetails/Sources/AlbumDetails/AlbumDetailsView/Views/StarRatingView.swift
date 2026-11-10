//
//  StarRatingView.swift
//  AlbumDetails
//
//  Created by Tomasz Wojtyniak on 31/07/2025.
//

import SwiftUI
import Models
import CoreUI

private struct StarView: View {
    let index: Int
    let rating: Double

    private var fill: StarRatingScale.Fill { StarRatingScale.fill(ofStar: index, rating: rating) }

    var body: some View {
        ZStack {
            Image(systemName: "star")
                .textStyle(.iconRating, color: .gray.opacity(0.3))
                .scaleEffect(1.3)

            if fill == .full {
                Image(systemName: "star.fill")
                    .textStyle(.iconRating, color: .accentPrimary)
                    .scaleEffect(1.3)
            } else if fill == .half {
                Image(systemName: "star.leadinghalf.filled")
                    .textStyle(.iconRating, color: .accentPrimary)
                    .scaleEffect(1.3)
            }
        }
    }
}

struct StarRatingView: View {
    @Binding var rating: Double
    var onRatingFinalized: ((Double) -> Void)?

    private let maxRating = StarRatingScale.starCount
    @State private var lastTappedStar: Int = -1
    @State private var lastTapTime: Date = .distantPast
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<maxRating, id: \.self) { index in
                StarView(index: index, rating: rating)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: rating)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            containerWidth = newWidth
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard containerWidth > 0 else { return }
                    updateRating(from: value.location)
                }
                .onEnded { value in
                    guard containerWidth > 0 else { return }
                    let isTap = value.translation.width.magnitude < 5 &&
                                value.translation.height.magnitude < 5
                    // `rating == 0` means the drag reached the dead zone left of
                    // the first half-star, i.e. the user cleared it. Honour that
                    // even when the movement was short enough to look like a tap —
                    // `handleTap` can only ever produce >= 0.5, so routing there
                    // would snap a low rating back up instead of removing it.
                    if isTap && rating > 0 {
                        handleTap(at: value.startLocation)
                    } else {
                        onRatingFinalized?(rating)
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: .ratingAccessibilityLabel))
        .accessibilityValue(
            rating == 0
                ? String(localized: .ratingNotRated)
                : String(localized: .ratingOutOfTen(rating: rating.formatted(.number.precision(.fractionLength(1)))))
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setRating(rating + 0.5)
                onRatingFinalized?(rating)
            case .decrement:
                setRating(rating - 0.5)
                onRatingFinalized?(rating)
            @unknown default:
                break
            }
        }
    }

    private func handleTap(at location: CGPoint) {
        let index = StarRatingScale.tappedStar(atX: location.x, width: containerWidth)
        let now = Date()
        let isQuickRepeat = lastTappedStar == index && now.timeIntervalSince(lastTapTime) < 0.5
        setRating(StarRatingScale.tapRating(star: index, isQuickRepeat: isQuickRepeat))

        lastTappedStar = index
        lastTapTime = now
        onRatingFinalized?(rating)
    }

    private func setRating(_ newRating: Double) {
        let clamped = StarRatingScale.clamped(newRating)
        if rating != clamped {
            rating = clamped
        }
    }

    private func updateRating(from location: CGPoint) {
        setRating(StarRatingScale.dragRating(atX: location.x, width: containerWidth))
    }
}

#Preview {
    StarRatingView(rating: .constant(7.8))
}
