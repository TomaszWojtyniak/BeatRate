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

            LogomarkView(
                style: .yellow,
                halo: Halo.large,
                haloBlur: Blur.haloMedium
            )

            WordmarkView()
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
