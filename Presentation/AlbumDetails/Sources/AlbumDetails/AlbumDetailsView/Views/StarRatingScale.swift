//
//  StarRatingScale.swift
//  AlbumDetails
//

import Foundation

/// The 0…10 star scale: ten stars, half-star steps.
enum StarRatingScale {
    static let starCount = 10
    static let maximum = 10.0

    enum Fill: Equatable {
        case empty, half, full
    }

    /// How much of the star at `index` a `rating` fills.
    static func fill(ofStar index: Int, rating: Double) -> Fill {
        let fill = rating - Double(index)
        if fill >= 1 { return .full }
        if fill >= 0.5 { return .half }
        return .empty
    }

    static func clamped(_ rating: Double) -> Double {
        min(max(rating, 0), maximum)
    }

    /// Rating while dragging across a row `width` wide: the inner half of a star
    /// rounds to a half star, its last quarter to the full one.
    static func dragRating(atX x: Double, width: Double) -> Double {
        let starWidth = width / Double(starCount)
        let clampedX = min(max(x, 0), width)
        let starIndex = Int(clampedX / starWidth)
        let remainder = clampedX.truncatingRemainder(dividingBy: starWidth) / starWidth

        var rating = Double(starIndex)
        if remainder > 0.75 {
            rating += 1
        } else if remainder > 0.25 {
            rating += 0.5
        }
        return clamped(rating)
    }

    /// The star a tap at `x` lands on.
    static func tappedStar(atX x: Double, width: Double) -> Int {
        min(Int(x / (width / Double(starCount))), starCount - 1)
    }

    /// A tap fills the star; a second quick tap on the same star halves it.
    static func tapRating(star index: Int, isQuickRepeat: Bool) -> Double {
        isQuickRepeat ? Double(index) + 0.5 : Double(index + 1)
    }
}
