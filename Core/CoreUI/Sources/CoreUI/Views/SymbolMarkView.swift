//
//  SymbolMarkView.swift
//  CoreUI
//

import SwiftUI

/// A large SF Symbol presented in the accent-gradient square, on a soft halo.
///
/// Shares its silhouette with ``LogomarkView`` but carries an arbitrary symbol
/// instead of the app icon — use it for full-screen moments that need their own
/// illustrative glyph (permission explainers, empty states) rather than the
/// brand mark.
public struct SymbolMarkView: View {
    private let systemName: String
    private let halo: CGFloat
    private let haloBlur: CGFloat

    /// - Parameters:
    ///   - systemName: SF Symbol name to render inside the gradient square.
    ///   - halo: Diameter of the blurred accent circle behind the mark.
    ///   - haloBlur: Blur radius applied to that circle.
    public init(
        systemName: String,
        halo: CGFloat = Halo.small,
        haloBlur: CGFloat = Blur.haloSmall
    ) {
        self.systemName = systemName
        self.halo = halo
        self.haloBlur = haloBlur
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentPrimarySoft)
                .frame(width: halo, height: halo)
                .blur(radius: haloBlur)

            RoundedRectangle(cornerRadius: Radius.logomark, style: .continuous)
                .fill(Color.accentPrimaryGradient)
                .frame(width: Size.logomark, height: Size.logomark)
                .overlay(
                    Image(systemName: systemName)
                        .resizable()
                        .scaledToFit()
                        .padding(Size.logomarkInset)
                        .foregroundStyle(Color.white.opacity(0.95))
                )
                .appShadow(.accentLift)
        }
    }
}
