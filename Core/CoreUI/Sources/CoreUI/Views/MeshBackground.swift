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
                .frame(width: 420, height: 420)
                .blur(radius: intense ? 100 : 80)
                .opacity(intense ? 0.35 : 0.65)
                .offset(x: -160, y: -240)

            // Secondary (blue) halo — bottom-right
            Circle()
                .fill(Color.accentSecondarySoft)
                .frame(width: 360, height: 360)
                .blur(radius: intense ? 100 : 80)
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
