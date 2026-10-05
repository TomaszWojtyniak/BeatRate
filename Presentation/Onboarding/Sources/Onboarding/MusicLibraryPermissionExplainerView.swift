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

                LogomarkView(style: .yellow)

                Text(.libraryAccessTitle)
                    .textStyle(.title, color: .primaryTextOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xl)

                Text(.libraryAccessMessage)
                    .textStyle(.body, color: .secondaryTextOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    MusicLibraryPermissionBullet(
                        icon: "magnifyingglass",
                        text: String(localized: .libraryAccessBulletSearch)
                    )
                    MusicLibraryPermissionBullet(
                        icon: "star.fill",
                        text: String(localized: .libraryAccessBulletRate)
                    )
                    MusicLibraryPermissionBullet(
                        icon: "music.note",
                        text: String(localized: .libraryAccessBulletOpen)
                    )
                }
                .padding(.top, Spacing.xl)
                .padding(.horizontal, Spacing.lg)

                Spacer()

                Button(action: onContinue) {
                    Text(.libraryAccessContinue)
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
