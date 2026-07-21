//
//  LogomarkView.swift
//  Login
//

import SwiftUI
import CoreUI

/// The app logomark with its soft accent halo.
struct LogomarkView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentPrimarySoft)
                .frame(width: Halo.small, height: Halo.small)
                .blur(radius: Blur.haloSmall)

            RoundedRectangle(cornerRadius: Radius.logomark, style: .continuous)
                .fill(Color.accentPrimaryGradient)
                .frame(width: Size.logomark, height: Size.logomark)
                .overlay(
                    Image(systemName: "star.square.on.square.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(Size.logomarkInset)
                        .foregroundStyle(Color.white.opacity(0.95))
                )
                .appShadow(.accentLift)
        }
    }
}
