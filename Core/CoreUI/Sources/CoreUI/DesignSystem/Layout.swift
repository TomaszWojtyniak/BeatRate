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
    /// 25 — third-party service connector icon (Apple Music, Spotify) in Settings rows.
    public static let connectorIcon:  CGFloat = 25
    /// 44 — minimum tappable touch target (Apple HIG), small chip / button square.
    public static let touchTarget:    CGFloat = 44
    /// 56 — search-row album cover.
    public static let thumbnailSmall: CGFloat = 56
    /// 84 — Account profile avatar.
    public static let avatar:         CGFloat = 84
    /// 124 — Login / Splash logomark square.
    public static let logomark:       CGFloat = 124
    /// 22 — SF Symbol inset within the Splash/Login logomark gradient square.
    public static let logomarkInset:  CGFloat = 22
    /// 138 — HomeSection grid album thumbnail.
    public static let thumbnailLarge: CGFloat = 138
    /// 280 — AlbumDetails hero cover.
    public static let coverHero:      CGFloat = 280
    /// 54 — Sign-In-with-Apple button height (Apple HIG).
    public static let signInButton:   CGFloat = 54
}

/// Decorative halo / blurred-circle dimensions.
/// Halos are visually-tuned shapes; tokens here keep call sites consistent.
/// Use as: `.frame(width: Halo.small, height: Halo.small)`.
public enum Halo {
    /// 260 — Login screen halo behind the logomark.
    public static let small:         CGFloat = 260
    /// 300 — Account profile-card halo behind the avatar.
    public static let medium:        CGFloat = 300
    /// 320 — Splash screen halo behind the logomark.
    public static let large:         CGFloat = 320
    /// 360 — Mesh background secondary (blue) halo.
    public static let meshSecondary: CGFloat = 360
    /// 420 — Mesh background primary (honey) halo.
    public static let meshPrimary:   CGFloat = 420
}

/// Blur radii for halos and decorative softening.
/// Use as: `.blur(radius: Blur.haloMedium)`.
public enum Blur {
    /// 2 — content dim while a loading HUD is on top.
    public static let contentDim:    CGFloat = 2
    /// 36 — Login halo blur.
    public static let haloSmall:     CGFloat = 36
    /// 40 — Splash / Account halo blur.
    public static let haloMedium:    CGFloat = 40
    /// 80 — Mesh background halo blur (standard mode).
    public static let meshStandard:  CGFloat = 80
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
