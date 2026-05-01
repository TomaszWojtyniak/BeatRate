//
//  AppShadow.swift
//  CoreUI
//
//  Unified shadow vocabulary. Six tiers, three roles:
//
//    Neutral elevation (depth on a surface):
//      .low      — small list rows, chips, secondary thumbnails
//      .medium   — cards, raised tiles, material backgrounds
//      .high     — hero artwork, full-bleed featured surfaces
//
//    Accent glow (honey-tinted lift on warm CTAs):
//      .accentGlow  — pills, buttons, avatars
//      .accentLift  — large logomark / hero card on dark backgrounds
//
//    Destructive:
//      .destructive — red glow for destructive CTAs (e.g. logout)
//
//  Every style internally layers an ambient soft shadow with a tight crisp one
//  where useful, so adding depth stays a one-line `.appShadow(.medium)` call.
//

import SwiftUI

public enum AppShadow {
    case low
    case medium
    case high
    case accentGlow
    case accentLift
    case destructive

    fileprivate var layers: [ShadowLayer] {
        switch self {
        case .low:
            return [.init(color: .black.opacity(0.12), radius: 6, y: 3)]
        case .medium:
            return [
                .init(color: .black.opacity(0.18), radius: 14, y: 8),
                .init(color: .black.opacity(0.06), radius: 2,  y: 1)
            ]
        case .high:
            return [
                .init(color: .black.opacity(0.30), radius: 26, y: 16),
                .init(color: .black.opacity(0.14), radius: 6,  y: 3)
            ]
        case .accentGlow:
            return [.init(color: .accentPrimaryGlow.opacity(0.6), radius: 12, y: 7)]
        case .accentLift:
            return [
                .init(color: .accentPrimaryGlow,   radius: 22, y: 12),
                .init(color: .black.opacity(0.22), radius: 10, y: 6)
            ]
        case .destructive:
            return [.init(color: .red.opacity(0.35), radius: 12, y: 6)]
        }
    }
}

private struct ShadowLayer {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

private struct AppShadowModifier: ViewModifier {
    let style: AppShadow

    func body(content: Content) -> some View {
        style.layers.reduce(AnyView(content)) { view, layer in
            AnyView(view.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y))
        }
    }
}

public extension View {
    /// Apply a named shadow from the unified app vocabulary.
    /// Prefer this over `.shadow(...)` so depth stays consistent across screens.
    func appShadow(_ style: AppShadow) -> some View {
        modifier(AppShadowModifier(style: style))
    }
}
