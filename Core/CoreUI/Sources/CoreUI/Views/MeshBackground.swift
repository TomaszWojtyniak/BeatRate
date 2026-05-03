//
//  MeshBackground.swift
//  CoreUI
//
//  Adds a depth-rich mesh background — primary + secondary radial halos
//  layered over the system base — for screens like Home, Account, Search.
//

import SwiftUI

public struct MeshBackground: View {
    /// When `true` halos are stronger (used on hero / album-detail screens).
    let intense: Bool

    public init(intense: Bool = false) {
        self.intense = intense
    }

    public var body: some View {
        ZStack {
            // Base color follows system light/dark
            Color(uiColor: .systemBackground)

            // Primary (yellow) halo — top-left
            Circle()
                .fill(Color.accentPrimarySoft)
                .frame(width: Halo.meshPrimary, height: Halo.meshPrimary)
                .blur(radius: intense ? Blur.meshIntense : Blur.meshStandard)
                .opacity(intense ? 0.35 : 0.65)
                .offset(x: -160, y: -240)

            // Secondary (blue) halo — bottom-right
            Circle()
                .fill(Color.accentSecondarySoft)
                .frame(width: Halo.meshSecondary, height: Halo.meshSecondary)
                .blur(radius: intense ? Blur.meshIntense : Blur.meshStandard)
                .opacity(intense ? 0.28 : 0.55)
                .offset(x: 160, y: 280)
        }
        .drawingGroup()       // rasterize the blurred halos once — no per-frame recompute
        .ignoresSafeArea()
    }
}

public extension View {
    /// Layers a depth-rich mesh background behind the receiver.
    func meshBackground(intense: Bool = false) -> some View {
        background(MeshBackground(intense: intense))
    }
}

#Preview {
    VStack { Text("Preview").font(.largeTitle) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .meshBackground()
}
