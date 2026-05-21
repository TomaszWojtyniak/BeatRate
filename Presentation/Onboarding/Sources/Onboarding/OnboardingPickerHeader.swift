//
//  OnboardingPickerHeader.swift
//  Onboarding
//

import SwiftUI
import CoreUI

struct OnboardingPickerHeader: View {
    let isOnboarding: Bool

    var body: some View {
        if isOnboarding {
            VStack(spacing: Spacing.sm) {
                Text("Pick your player")
                    .textStyle(.title, color: .primaryTextOnDark)
                    .multilineTextAlignment(.center)

                Text("Where albums you tap will open. You can change it later in Settings.")
                    .textStyle(.body, color: .secondaryTextOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
        } else {
            // In Settings (change mode) the navbar already shows "Main music player",
            // so we only need a single helper line.
            Text("Where albums you tap will open.")
                .textStyle(.body, color: .secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
    }
}
