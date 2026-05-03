//
//  Typography.swift
//  CoreUI
//
//  Named text styles for the entire app. Every screen should pick a role from
//  this list rather than hand-rolling `.font(.system(size: …, weight: …))`.
//
//  Each style bundles font + default colour. Apply via `.textStyle(.title)`.
//  To override the colour for a call site, pass it via the `color:` parameter:
//  `.textStyle(.bodyEmphasis, color: .accentPrimary)`. Do NOT chain a trailing
//  `.foregroundStyle` — chaining can render unpredictably under certain modifier
//  orderings (e.g. on dark backgrounds where the role's adaptive default would
//  resolve to a dark colour). The `color:` slot keeps colour logic in one place.
//

import SwiftUI

public enum AppTextStyle {

    // MARK: – Brand display (large wordmarks)

    /// 70pt / semibold — Login screen "BeatRate" wordmark.
    case displayHero
    /// 42pt / bold — Splash screen "BeatRate" wordmark.
    case displayLarge

    // MARK: – Page titles

    /// 32pt / bold — Album hero title on AlbumDetails.
    case title
    /// 28pt / bold — Account profile card display name.
    case displayName
    /// 34pt / rounded / bold — Account profile card avatar initials.
    case avatarInitials
    /// `.title2` / bold — Section headers ("New Releases", "Ratings").
    case titleSection

    // MARK: – Numeric stats

    /// `.title2` / rounded / bold — Stat-tile values, primary rating display.
    case statValue
    /// 26pt / rounded / bold — Account mini-stat numbers.
    case statValueCompact

    // MARK: – Body

    /// `.subheadline` / semibold — Button labels, primary action text, list-row titles.
    case bodyEmphasis
    /// `.subheadline` — Body copy, descriptions, supporting text.
    case body
    /// `.title3` / medium — Album artist, secondary detail text.
    case secondaryDetail

    // MARK: – Captions / metadata

    /// `.footnote` / semibold — Chip labels, link text ("See all", "Edit profile").
    case captionEmphasis
    /// `.footnote` — Secondary metadata, helper text.
    case caption
    /// `.caption2` / rounded / semibold — Uppercased tile labels ("RATING", "RELEASED").
    case label
    /// `.caption2` / monospaced — Build / version strings.
    case mono

    // MARK: – Icon glyph sizes (SF Symbols sized via .font)
    //
    // SF Symbols inherit sizing/weight from `.font` just like text. These
    // roles let symbol-only views like chip leading-icons or large
    // placeholder glyphs go through the same typography vocabulary as text.
    //   - colour: inherits from the surrounding `.foregroundStyle(...)`,
    //     not from the role's default; tracking is a no-op on symbols.

    /// `.caption2` / semibold — small SF Symbol paired with a label (e.g. StatTile leading icon).
    case iconLabel
    /// 11pt / semibold — SF Symbol leading a caption chip (e.g. genre chip).
    case iconChip
    /// 12pt / semibold — list-row trailing accessory (e.g. chevron).
    case iconRowAccessory
    /// 20pt / bold — SF Symbol inside an action chip (e.g. RateAlbum star chip).
    case iconAction
    /// `.title3` — interactive rating stars.
    case iconRating
    /// 36pt — placeholder SF Symbol for album thumbnails.
    case iconPlaceholder
    /// 50pt — placeholder SF Symbol behind a hero cover (AlbumDetails).
    case iconHero

    public var font: Font {
        switch self {
        case .displayHero:       return .system(size: 70, weight: .semibold)
        case .displayLarge:      return .system(size: 42, weight: .bold)
        case .title:             return .system(size: 32, weight: .bold)
        case .displayName:       return .system(size: 28, weight: .bold)
        case .avatarInitials:    return .system(size: 34, weight: .bold, design: .rounded)
        case .titleSection:      return .system(.title2, weight: .bold)
        case .statValue:         return .system(.title2, design: .rounded, weight: .bold)
        case .statValueCompact:  return .system(size: 26, weight: .bold, design: .rounded)
        case .bodyEmphasis:      return .system(.subheadline, weight: .semibold)
        case .body:              return .system(.subheadline)
        case .secondaryDetail:   return .system(.title3, weight: .medium)
        case .captionEmphasis:   return .system(.footnote, weight: .semibold)
        case .caption:           return .system(.footnote)
        case .label:             return .system(.caption2, design: .rounded, weight: .semibold)
        case .mono:              return .system(.caption2, design: .monospaced)
        case .iconLabel:         return .system(.caption2, weight: .semibold)
        case .iconChip:          return .system(size: 11, weight: .semibold)
        case .iconRowAccessory:  return .system(size: 12, weight: .semibold)
        case .iconAction:        return .system(size: 20, weight: .bold)
        case .iconRating:        return .system(.title3)
        case .iconPlaceholder:   return .system(size: 36)
        case .iconHero:          return .system(size: 50)
        }
    }

    /// Default foreground colour. Override per call site via the `color:`
    /// parameter on `.textStyle(_:color:)` — never chain a trailing
    /// `.foregroundStyle` after `.textStyle`.
    public var color: Color {
        switch self {
        case .caption, .mono, .label:
            return .secondaryText
        default:
            return .primaryText
        }
    }

    /// Default letter-spacing tweak. Pulls slightly tighter on big titles for
    /// a more "Apple" feel; widens slightly on uppercased labels.
    public var tracking: CGFloat {
        switch self {
        case .displayHero:                          return -1.5
        case .displayLarge:                         return -1.0
        case .title:                                return -0.8
        case .displayName:                          return -0.6
        case .avatarInitials:                       return -0.5
        case .titleSection:                         return -0.4
        case .statValueCompact:                     return -0.5
        case .label:                                return 0.6
        default:                                    return 0
        }
    }
}

public extension View {
    /// Apply a named text style: bundles font, default foreground colour, and tracking.
    /// Prefer this over hand-rolled `.font(.system(...))` so typography stays consistent.
    ///
    /// - Parameter color: Override the role's default foreground colour. Pass `nil`
    ///   to keep the role's default. Useful for accent links (e.g. honey "See all")
    ///   and fixed-light buttons on coloured backgrounds.
    func textStyle(_ style: AppTextStyle, color: Color? = nil) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color ?? style.color)
    }

    /// Apply a named text style with a non-`Color` foreground — for `ShapeStyle`
    /// values like `.secondary`, `.tertiary`, gradients, or materials. Use this
    /// instead of chaining a trailing `.foregroundStyle(...)` after `.textStyle(...)`,
    /// since chaining can render unpredictably under certain modifier orderings.
    func textStyle<S: ShapeStyle>(_ style: AppTextStyle, foreground: S) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(foreground)
    }
}
