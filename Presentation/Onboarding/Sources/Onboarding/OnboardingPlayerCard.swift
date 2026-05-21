//
//  OnboardingPlayerCard.swift
//  Onboarding
//

import SwiftUI
import Models
import CoreUI

struct OnboardingPlayerCard: View {
    let player: MusicPlayer
    let isOnboarding: Bool
    let isSelected: Bool
    let isPending: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isPending ? 0.6 : 1)
    }

    @ViewBuilder
    private var content: some View {
        if isOnboarding {
            cardRow
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(onGradientBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.surfaceStrokeSelected : Color.surfaceOnGradientStroke,
                            lineWidth: Stroke.hairline
                        )
                )
                .appShadow(.medium)
        } else {
            cardRow
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .roundedMaterialBackground()
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.surfaceStrokeSelected : Color.surfaceStroke,
                            lineWidth: Stroke.hairline
                        )
                )
        }
    }

    private var cardRow: some View {
        HStack(spacing: Spacing.md) {
            Image(iconName, bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Size.thumbnailSmall, height: Size.thumbnailSmall)
                .clipShape(.rect(cornerRadius: Radius.medium, style: .continuous))
                .appShadow(.low)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(player.displayName)
                    .textStyle(.bodyEmphasis, color: titleColor)
                Text(subtitle)
                    .textStyle(.caption, color: subtitleColor)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: Spacing.xs)

            trailingAccessory
        }
    }

    @ViewBuilder
    private var onGradientBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        shape
            .fill(Color.surfaceOnGradientFill)
            .overlay(shape.fill(Color.surfaceOnGradientSheen))
    }

    private var titleColor: Color {
        isOnboarding ? .primaryTextOnDark : .primaryText
    }

    private var subtitleColor: Color {
        isOnboarding ? .secondaryTextOnDark : .secondaryText
    }

    private var iconName: String {
        switch player {
        case .appleMusic: "apple_music_logo_icon"
        case .spotify: "spotify_logo_icon"
        }
    }

    private var subtitle: String {
        switch player {
        case .appleMusic: "Open albums in Apple Music."
        case .spotify: "Open albums in Spotify, sync recommendations."
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isPending {
            ProgressView()
                .tint(Color.accentPrimary)
        } else if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .textStyle(.iconAction, color: .accentPrimary)
        } else {
            Image(systemName: "chevron.right")
                .textStyle(.iconRowAccessory, foreground: .tertiary)
        }
    }

}
