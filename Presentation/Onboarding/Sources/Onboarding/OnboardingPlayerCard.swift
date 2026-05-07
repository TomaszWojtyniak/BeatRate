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
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: Stroke.hairline)
            )
            .appShadow(.medium)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isPending ? 0.6 : 1)
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
                .font(.title2)
                .foregroundStyle(Color.accentPrimary)
        } else {
            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        if isOnboarding {
            shape
                .fill(Color.black.opacity(0.22))
                .overlay(
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
        } else {
            shape.fill(.regularMaterial)
        }
    }

    private var strokeColor: Color {
        if isOnboarding {
            return isSelected
                ? Color.accentPrimary.opacity(0.55)
                : Color.white.opacity(0.14)
        } else {
            return isSelected ? Color.accentPrimary.opacity(0.6) : Color.surfaceStroke
        }
    }
}
