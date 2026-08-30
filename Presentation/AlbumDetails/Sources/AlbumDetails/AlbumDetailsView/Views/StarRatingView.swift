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

    private var fill: Double { rating - Double(index) }

    var body: some View {
        ZStack {
            Image(systemName: "star")
                .textStyle(.iconRating, color: .gray.opacity(0.3))
                .scaleEffect(1.3)

            if fill >= 1.0 {
                Image(systemName: "star.fill")
                    .textStyle(.iconRating, color: .accentPrimary)
                    .scaleEffect(1.3)
            } else if fill >= 0.5 {
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

    private let maxRating: Int = 10
    private let totalScale: Double = 10.0
    @State private var lastTappedStar: Int = -1
    @State private var lastTapTime: Date = .distantPast
    @State private var containerWidth: CGFloat = 0

    private var starWidth: CGFloat {
        containerWidth > 0 ? containerWidth / CGFloat(maxRating) : 1
    }

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
        .accessibilityLabel("Album rating")
        .accessibilityValue(rating == 0 ? "Not rated" : String(format: "%.1f out of 10", rating))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setRating(min(rating + 0.5, totalScale))
                onRatingFinalized?(rating)
            case .decrement:
                setRating(max(rating - 0.5, 0))
                onRatingFinalized?(rating)
            @unknown default:
                break
            }
        }
    }

    private func handleTap(at location: CGPoint) {
        let index = min(Int(location.x / starWidth), maxRating - 1)
        let now = Date()

        if lastTappedStar == index && now.timeIntervalSince(lastTapTime) < 0.5 {
            setRating(Double(index) + 0.5)
        } else {
            setRating(Double(index + 1))
        }

        lastTappedStar = index
        lastTapTime = now
        onRatingFinalized?(rating)
    }

    private func setRating(_ newRating: Double) {
        let clamped = min(max(newRating, 0), totalScale)
        if rating != clamped {
            rating = clamped
        }
    }

    private func updateRating(from location: CGPoint) {
        let clampedX = min(max(location.x, 0), containerWidth)
        let starIndex = Int(clampedX / starWidth)
        let remainder = clampedX.truncatingRemainder(dividingBy: starWidth) / starWidth

        var newRating = Double(starIndex)
        if remainder > 0.75 {
            newRating += 1.0
        } else if remainder > 0.25 {
            newRating += 0.5
        }

        setRating(newRating)
    }
}

#Preview {
    StarRatingView(rating: .constant(7.8))
}
