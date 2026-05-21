//
//  SplashContentView.swift
//  Splash
//

import SwiftUI
import CoreUI

struct SplashContentView: View {
    let isRetrying: Bool
    let errorMessage: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentPrimarySoft)
                    .frame(width: Halo.large, height: Halo.large)
                    .blur(radius: Blur.haloMedium)

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

            Text("login.app.name", bundle: .module)
                .textStyle(.displayLarge, color: .accentPrimary)
                .padding(.top, Spacing.xl)

            Text("Rate every album.")
                .textStyle(.body, color: .secondaryTextOnDark)
                .padding(.top, Spacing.xxs)

            Spacer()

            if isRetrying {
                VStack(spacing: Spacing.xs) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text(errorMessage)
                        .textStyle(.caption, color: .primaryTextOnDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, Spacing.lg)
            } else {
                ProgressView()
                    .tint(Color.accentPrimary)
                    .padding(.bottom, Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xl)
        .background(Color.backgroundGradient)
    }
}
