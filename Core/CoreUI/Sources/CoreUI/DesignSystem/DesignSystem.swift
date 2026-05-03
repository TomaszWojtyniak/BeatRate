//
//  DesignSystem.swift
//  CoreUI
//
//  Design tokens for the entire app. Use these instead of magic numbers in
//  `.padding(...)`, `VStack(spacing: ...)`, `RoundedRectangle(cornerRadius: ...)`,
//  etc. Keeping the vocabulary tiny makes layouts feel consistent across screens.
//

import Foundation
import CoreGraphics

/// Six-step spacing scale on a 4-point grid.
/// Use as: `.padding(.horizontal, Spacing.lg)`, `VStack(spacing: Spacing.md)`.
public enum Spacing {
    /// 4 — hairline gaps between tightly related labels (e.g. title + subtitle).
    public static let xxs: CGFloat = 4
    /// 8 — gaps inside a row, label-to-icon, chip padding.
    public static let xs:  CGFloat = 8
    /// 12 — default inner gutter for stacks, default tile spacing.
    public static let sm:  CGFloat = 12
    /// 16 — section-internal padding, common card padding.
    public static let md:  CGFloat = 16
    /// 20 — outer screen-edge horizontal padding, between top-level sections.
    public static let lg:  CGFloat = 20
    /// 32 — bottom safe-bottom padding, large vertical breathing room.
    public static let xl:  CGFloat = 32
}

/// Three-step corner-radius scale, plus two Apple-HIG-specified component radii.
/// Use as: `RoundedRectangle(cornerRadius: Radius.large)`.
public enum Radius {
    /// 12 — chips, small thumbnails, search-row covers.
    public static let small:        CGFloat = 12
    /// 18 — album hero cover, medium feature surfaces.
    public static let medium:       CGFloat = 18
    /// 22 — section cards, material backgrounds, stat tiles.
    public static let large:        CGFloat = 22
    /// 28 — Splash/Login logomark (Apple-HIG continuous radius).
    public static let logomark:     CGFloat = 28
    /// 14 — Sign-In-with-Apple button (Apple-HIG continuous radius).
    public static let signInButton: CGFloat = 14
}
