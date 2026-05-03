//
//  StatTile.swift
//  CoreUI
//
//  A tinted stat tile — used on Album Details for "Rating" and "Released"
//  and in similar at-a-glance displays. The icon decorates the label so the
//  numeric value below stays the visual hero.
//

import SwiftUI

public struct StatTile<Content: View>: View {
    let label: String
    /// Optional SF Symbol shown next to the label. Pass `nil` to omit.
    let systemImage: String?
    /// Tint of the icon — defaults to the tile's own tint colour family.
    let iconColor: Color
    /// Tint wash colour (e.g. `.accentPrimaryTint`, `.accentSecondaryTint`).
    let tint: Color
    let content: () -> Content

    public init(
        label: String,
        systemImage: String? = nil,
        iconColor: Color = .secondary,
        tint: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.tint = tint
        self.content = content
    }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .textStyle(.iconLabel, color: iconColor)
                }
                Text(label.uppercased())
                    .textStyle(.label, foreground: .tertiary)
            }

            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(tint)
        )
        .roundedMaterialBackground()
    }
}

#Preview {
    HStack(spacing: 12) {
        StatTile(label: "Rating",
                 systemImage: "star.fill",
                 iconColor: .accentPrimary,
                 tint: .accentPrimaryTint) {
            Text("8.4").textStyle(.statValue)
        }
        StatTile(label: "Released",
                 systemImage: "calendar",
                 iconColor: .accentSecondary,
                 tint: .accentSecondaryTint) {
            Text("2024").textStyle(.statValue)
        }
    }
    .padding()
    .meshBackground()
}
