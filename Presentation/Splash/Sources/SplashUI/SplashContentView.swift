//
//  SplashContentView.swift
//  Splash
//

#if os(iOS)
import SwiftUI
import CoreUI

struct SplashContentView: View {
    /// Why the sections are being fetched again, or nil on the first attempt.
    let retryMessage: String?

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

            Text(.splashTagline)
                .textStyle(.body, color: .secondaryTextOnDark)
                .padding(.top, Spacing.xxs)

            Spacer()

            if let retryMessage {
                VStack(spacing: Spacing.xs) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text(retryMessage)
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
#endif
