//
//  MeshBackground.swift
//  CoreUI
//
//  Adds a depth-rich mesh background — primary + secondary radial halos
//  layered over the system base — for screens like Home, Account, Search.
//

import SwiftUI

public struct MeshBackground: View {
    /// Fill for the top-left halo. Pass already-softened colours (e.g.
    /// `.accentPrimarySoft` or `.opacity(0.2)`-attenuated artwork colours);
    /// the view's own `.opacity(...)` is on top of whatever you pass.
    let primary: Color
    /// Fill for the bottom-right halo (same alpha guidance as `primary`).
    let secondary: Color

    public init(
        primary: Color = .accentPrimarySoft,
        secondary: Color = .accentSecondarySoft
    ) {
        self.primary = primary
        self.secondary = secondary
    }

    public var body: some View {
        ZStack {
            // Base color follows system light/dark
            Color(uiColor: .systemBackground)

            // Primary halo — top-left
            Circle()
                .fill(primary)
                .frame(width: Halo.meshPrimary, height: Halo.meshPrimary)
                .blur(radius: Blur.meshStandard)
                .opacity(0.95)
                .offset(x: -160, y: -240)

            // Secondary halo — bottom-right
            Circle()
                .fill(secondary)
                .frame(width: Halo.meshSecondary, height: Halo.meshSecondary)
                .blur(radius: Blur.meshStandard)
                .opacity(0.85)
                .offset(x: 160, y: 280)
        }
        .drawingGroup()       // rasterize the blurred halos once — no per-frame recompute
        .ignoresSafeArea()
    }
}

public extension View {
    /// Layers a depth-rich mesh background behind the receiver.
    /// Pass `primary` / `secondary` to tint the halos (e.g. with album-cover
    /// colours via `ArtworkColors.extract(from:)`); omit for the default
    /// honey + blue accent halos.
    func meshBackground(
        primary: Color = .accentPrimarySoft,
        secondary: Color = .accentSecondarySoft
    ) -> some View {
        background(MeshBackground(primary: primary, secondary: secondary))
    }
}

#Preview {
    VStack { Text("Preview").font(.largeTitle) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .meshBackground()
}
