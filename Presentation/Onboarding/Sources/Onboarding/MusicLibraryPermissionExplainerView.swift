//
//  MusicLibraryPermissionExplainerView.swift
//  Onboarding
//

import SwiftUI
import CoreUI

public struct MusicLibraryPermissionExplainerView: View {
    private let onContinue: () -> Void

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            Color.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.accentPrimarySoft)
                        .frame(width: Halo.small, height: Halo.small)
                        .blur(radius: Blur.haloSmall)

                    RoundedRectangle(cornerRadius: Radius.logomark, style: .continuous)
                        .fill(Color.accentPrimaryGradient)
                        .frame(width: Size.logomark, height: Size.logomark)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .resizable()
                                .scaledToFit()
                                .padding(Size.logomarkInset)
                                .foregroundStyle(Color.white.opacity(0.95))
                        )
                        .appShadow(.accentLift)
                }

                Text("Music library access")
                    .textStyle(.title, color: .primaryTextOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xl)

                Text("BeatRate uses Apple Music's catalog to show you new releases, fetch album metadata and tracklists, and let you rate every album you listen to.")
                    .textStyle(.body, color: .secondaryTextOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    MusicLibraryPermissionBullet(
                        icon: "magnifyingglass",
                        text: "Search the full Apple Music catalog."
                    )
                    MusicLibraryPermissionBullet(
                        icon: "star.fill",
                        text: "Rate albums and keep your taste in one place."
                    )
                    MusicLibraryPermissionBullet(
                        icon: "music.note",
                        text: "Open albums in your music player of choice."
                    )
                }
                .padding(.top, Spacing.xl)
                .padding(.horizontal, Spacing.lg)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .textStyle(.bodyEmphasis, color: .primaryTextOnDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: Size.signInButton)
                        .background(Capsule().fill(Color.accentPrimaryGradient))
                        .appShadow(.accentGlow)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
    }

}

#Preview {
    MusicLibraryPermissionExplainerView(onContinue: {})
}
