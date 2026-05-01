//
//  Layout.swift
//  CoreUI
//
//  Fixed pixel sizes and stroke widths used across the app. Pair with
//  `Spacing` and `Radius` for a complete layout vocabulary.
//

import Foundation
import CoreGraphics

/// Fixed component sizes — avatars, thumbnails, touch targets, hero artwork.
/// Use as: `.frame(width: Size.thumbnailLarge, height: Size.thumbnailLarge)`.
public enum Size {
    /// 44 — minimum tappable touch target (Apple HIG), small chip / button square.
    public static let touchTarget:    CGFloat = 44
    /// 56 — search-row album cover.
    public static let thumbnailSmall: CGFloat = 56
    /// 84 — Account profile avatar.
    public static let avatar:         CGFloat = 84
    /// 124 — Login / Splash logomark square.
    public static let logomark:       CGFloat = 124
    /// 138 — HomeSection grid album thumbnail.
    public static let thumbnailLarge: CGFloat = 138
    /// 280 — AlbumDetails hero cover.
    public static let coverHero:      CGFloat = 280
    /// 54 — Sign-In-with-Apple button height (Apple HIG).
    public static let signInButton:   CGFloat = 54
}

/// Stroke / border widths.
/// Use as: `.stroke(Color.surfaceStroke, lineWidth: Stroke.hairline)`.
public enum Stroke {
    /// 0.5 — hairline borders, dividers, chip outlines.
    public static let hairline: CGFloat = 0.5
    /// 1 — standard inner highlight or edge stroke.
    public static let thin:     CGFloat = 1
    /// 3 — thick decorative ring (Account avatar conic).
    public static let thick:    CGFloat = 3
}
