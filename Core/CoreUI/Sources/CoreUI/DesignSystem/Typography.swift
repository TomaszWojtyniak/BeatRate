//
//  Typography.swift
//  CoreUI
//
//  Named text styles for the entire app. Every screen should pick a role from
//  this list rather than hand-rolling `.font(.system(size: …, weight: …))`.
//
//  Each style bundles font + default colour. Apply via `.textStyle(.title)`.
//  If you need a non-default colour for a one-off, chain `.foregroundStyle(…)`
//  after `.textStyle(…)` — but think twice; if it's needed twice, add a role.
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

    public var font: Font {
        switch self {
        case .displayHero:       return .system(size: 70, weight: .semibold)
        case .displayLarge:      return .system(size: 42, weight: .bold)
        case .title:             return .system(size: 32, weight: .bold)
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
        }
    }

    /// Default foreground colour. Override with a chained `.foregroundStyle(…)`
    /// if you need a one-off (e.g. accent-coloured "See all" link).
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
}
