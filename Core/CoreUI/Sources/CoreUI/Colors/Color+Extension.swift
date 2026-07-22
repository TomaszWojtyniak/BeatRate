//
//  Color+Extension.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 09/06/2025.
//

import SwiftUI
import UIKit

private func dynamicColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? dark : light
    })
}

private func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> UIColor {
    UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}

public extension Color {

    // MARK: – Surfaces

    /// Page background for every screen. Adaptive: warm off-white in light mode, near-black in dark mode.
    static let backgroundColor: Color = dynamicColor(
        light: rgb(248, 245, 240),
        dark:  rgb(18, 18, 20)
    )

    /// Placeholder fill shown behind album artwork while it loads.
    static let albumPlaceholderColor: Color = .gray.opacity(0.3)

    // MARK: – Text

    /// Primary foreground for titles, body copy, and prominent labels.
    /// Adaptive: deep charcoal in light mode, warm cream in dark mode (WCAG AA on both backgrounds).
    static let primaryText: Color = dynamicColor(
        light: rgb(28, 28, 30),
        dark:  rgb(245, 225, 200)
    )

    /// Secondary foreground for subtitles, captions, and supporting metadata.
    /// Adaptive: mid-grey in light mode, soft warm grey in dark mode.
    static let secondaryText: Color = dynamicColor(
        light: rgb(96, 96, 102),
        dark:  rgb(200, 195, 185)
    )

    /// Fixed light primary text — always warm cream.
    /// Use on permanently dark surfaces (splash, login) where adaptive text would
    /// turn dark in light mode and vanish against the gradient.
    static let primaryTextOnDark: Color = Color(red: 245/255, green: 225/255, blue: 200/255)

    /// Fixed light secondary text — always soft warm grey.
    /// Companion to `primaryTextOnDark` for captions/metadata on dark surfaces.
    static let secondaryTextOnDark: Color = Color(red: 200/255, green: 195/255, blue: 185/255)

    /// Dimming layer behind full-screen modal overlays (e.g. the share card).
    static let scrim: Color = .black.opacity(0.9)

    // MARK: – Primary accent (honey yellow)

    /// Brand honey yellow (#E6B655). Identical in light and dark mode.
    /// Used for star ratings, primary CTAs, brand highlights, and the "rated/score" stat.
    static let accentPrimary: Color = Color(red: 230/255, green: 182/255, blue: 85/255)

    /// Deeper honey shade used as the bottom stop of `accentPrimaryGradient`
    /// and for pressed states on primary buttons.
    static let accentPrimaryDeep: Color = Color(red: 200/255, green: 148/255, blue: 50/255)

    /// 18% honey tint. Used for soft accent halos behind avatars and ratings.
    static let accentPrimarySoft: Color = .accentPrimary.opacity(0.18)

    /// 10% honey tint. Used for subtle stat-tile backgrounds.
    static let accentPrimaryTint: Color = .accentPrimary.opacity(0.10)

    /// 50% honey tint. Used as the drop-shadow glow under primary CTAs and the avatar ring.
    static let accentPrimaryGlow: Color = .accentPrimary.opacity(0.50)

    /// Vertical honey gradient (primary → deep). Fill for the "Edit profile" pill,
    /// hero album rating chips, and other accent-filled buttons.
    static let accentPrimaryGradient = LinearGradient(
        colors: [.accentPrimary, .accentPrimaryDeep],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: – Secondary accent (blue)

    /// Secondary accent — sapphire in light mode, sky blue in dark mode.
    /// Used for time/date/calendar/links and the "rated count" stat on Account.
    static let accentSecondary: Color = dynamicColor(
        light: rgb(10, 100, 220),
        dark:  rgb(90, 174, 255)
    )

    /// Soft tint of the secondary accent — used for backdrop halos in the mesh background.
    static let accentSecondarySoft: Color = dynamicColor(
        light: rgb(10, 100, 220, 0.18),
        dark:  rgb(90, 174, 255, 0.20)
    )

    /// 10% blue tint. Used for the "Released" stat-tile background, paired with `accentPrimaryTint`.
    static let accentSecondaryTint: Color = dynamicColor(
        light: rgb(10, 100, 220, 0.08),
        dark:  rgb(90, 174, 255, 0.12)
    )

    // MARK: – Status

    /// Adaptive red used for error text. Slightly brighter in dark mode for legibility
    /// against the warm cream foreground; deeper in light mode against the off-white
    /// background.
    static let errorRed: Color = dynamicColor(
        light: rgb(200, 40, 50),
        dark:  rgb(255, 95, 100)
    )

    /// Hairline stroke used on adaptive card surfaces. Pairs with `Stroke.hairline`.
    /// Subtle in both light and dark — just enough to define the edge.
    static let surfaceStroke: Color = dynamicColor(
        light: rgb(0, 0, 0, 0.08),
        dark:  rgb(255, 255, 255, 0.10)
    )

    /// Honey accent border used when a selectable surface is in the selected state.
    /// Pairs with `Color.surfaceStroke` for the default state.
    static let surfaceStrokeSelected: Color = .accentPrimary.opacity(0.55)

    /// Tinted-dark fill for cards placed on the brand `backgroundGradient` (Splash/Login/
    /// onboarding gradient). `.roundedMaterialBackground()` is for adaptive surfaces;
    /// this is its fixed-dark cousin.
    static let surfaceOnGradientFill: Color = .black.opacity(0.22)

    /// Top-down glass sheen used over `surfaceOnGradientFill` so dark cards on the
    /// brand gradient read as glass rather than a flat tile.
    static let surfaceOnGradientSheen = LinearGradient(
        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Hairline edge used on `surfaceOnGradientFill` cards in the default (unselected) state.
    static let surfaceOnGradientStroke: Color = .white.opacity(0.14)

    /// Fixed-dark tint applied to Liquid Glass that sits over photographic media
    /// (e.g. album artwork) so light foreground content — white text, the honey
    /// rating star — stays legible regardless of the cover's luminance.
    /// Used by `RatingChip` over Home album covers.
    static let glassTintOnMedia: Color = .black.opacity(0.5)

    // MARK: – Decorative gradients

    /// Full-bleed background gradient used by the Splash and Login screens.
    /// Derived from the secondary blue family — deep sapphire fading into near-black navy,
    /// so it reads as the "dark surface cousin" of `accentSecondary`.
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 28/255, green: 58/255, blue: 120/255),  // deep sapphire (top)
            Color(red: 6/255,  green: 18/255, blue: 52/255)    // near-black navy (bottom)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Apple Music brand gradient — pink-red to deep magenta. Used for the
    /// "Open in Apple Music" CTA on AlbumDetails. Matches Apple Music's
    /// in-app brand pill so the link reads as native.
    static let appleMusicGradient = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.18, blue: 0.33),
            Color(red: 0.98, green: 0.10, blue: 0.45)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Spotify brand gradient — signature green to a deeper green.
    /// Used for the "Open in Spotify" CTA on AlbumDetails.
    static let spotifyGradient = LinearGradient(
        colors: [
            Color(red: 0.11, green: 0.73, blue: 0.33),
            Color(red: 0.05, green: 0.50, blue: 0.22)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Conic gradient used as the avatar ring on the Account screen
    /// (cycles honey → blue → deep honey → honey).
    static let avatarConic = AngularGradient(
        gradient: Gradient(colors: [.accentPrimary, .accentSecondary, .accentPrimaryDeep, .accentPrimary]),
        center: .center,
        startAngle: .degrees(230),
        endAngle: .degrees(230 + 360)
    )
}
