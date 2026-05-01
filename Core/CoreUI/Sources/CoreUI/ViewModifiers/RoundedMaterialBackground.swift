//
//  RoundedMaterialBackground.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 02/08/2025.
//

import SwiftUI

/// Rounded card background using iOS 26 Liquid Glass.
///
/// Liquid Glass handles its own translucency, edge highlights and inner stroke —
/// we only add an outer drop shadow for depth via `AppShadow`. Hero/profile tiles
/// can opt into a faint honey tint via `hi: true`.
public struct RoundedMaterialBackground: ViewModifier {
    /// When `true`, applies a faint honey tint to the glass for hero/profile tiles.
    let hi: Bool
    /// Corner radius of the glass shape.
    let cornerRadius: CGFloat

    public init(hi: Bool = false, cornerRadius: CGFloat = 22) {
        self.hi = hi
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .glassEffect(
                hi ? .regular.tint(Color.accentPrimary.opacity(0.35)) : .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
            .appShadow(.medium)
    }
}

public extension View {
    /// Rounded Liquid Glass card.
    ///
    /// - Parameters:
    ///   - hi: Apply a faint honey tint to the glass — used on hero/profile tiles.
    ///   - cornerRadius: Corner radius of the glass shape.
    func roundedMaterialBackground(hi: Bool = false,
                                   cornerRadius: CGFloat = 22) -> some View {
        modifier(RoundedMaterialBackground(hi: hi, cornerRadius: cornerRadius))
    }
}
