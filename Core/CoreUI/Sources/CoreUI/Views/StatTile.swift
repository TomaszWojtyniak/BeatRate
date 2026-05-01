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
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(label.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.tertiary)
            }

            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
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
            Text("8.4")
                .font(.system(.title, design: .rounded, weight: .bold))
        }
        StatTile(label: "Released",
                 systemImage: "calendar",
                 iconColor: .accentSecondary,
                 tint: .accentSecondaryTint) {
            Text("2024")
                .font(.system(.title, design: .rounded, weight: .bold))
        }
    }
    .padding()
    .meshBackground()
}
