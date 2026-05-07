//
//  OnboardingPickerBackground.swift
//  Onboarding
//

import SwiftUI
import CoreUI

struct OnboardingPickerBackground: View {
    let isOnboarding: Bool

    var body: some View {
        if isOnboarding {
            ZStack {
                Color.backgroundGradient
                    .ignoresSafeArea()

                Circle()
                    .fill(Color.accentPrimarySoft)
                    .frame(width: Halo.medium, height: Halo.medium)
                    .blur(radius: Blur.haloMedium)
                    .offset(y: -260)
                    .allowsHitTesting(false)
            }
        } else {
            Color.backgroundColor
                .ignoresSafeArea()
        }
    }
}
