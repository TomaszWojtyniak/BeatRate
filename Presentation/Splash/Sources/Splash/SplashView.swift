//
//  SplashView.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import CoreUI

@MainActor
public struct SplashView: View {

    @State private var dataModel: SplashDataModel = SplashDataModel()

    let onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { dataModel.alertType != nil },
            set: { if !$0 { dataModel.alertType = nil } }
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logomark with soft accent halo for depth
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

            // Wordmark
            Text("login.app.name", bundle: .module)
                .textStyle(.displayLarge, color: .accentPrimary)
                .padding(.top, Spacing.xl)

            // Tagline
            Text("Rate every album.")
                .textStyle(.body, color: .secondaryTextOnDark)
                .padding(.top, Spacing.xxs)

            Spacer()

            // Show retry status if retrying — otherwise iOS-style activity indicator
            if dataModel.isRetrying {
                VStack(spacing: Spacing.xs) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text(dataModel.errorMessage)
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
        .task {
            await dataModel.loadInitialData()
            // Only proceed if there are no critical errors
            if dataModel.shouldComplete {
                onComplete()
            }
            // If shouldComplete is false, we stay on splash screen with error alert
        }
        .alert(
            dataModel.alertType == .connectionError ? "Connection Error" : "Apple Music Access Required",
            isPresented: isAlertPresented
        ) {
            if dataModel.alertType == .musicKitDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Try Again") {
                    Task {
                        await dataModel.retryAfterSettingsChange()
                        if dataModel.shouldComplete {
                            onComplete()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    Task {
                        await dataModel.logout()
                        onComplete()
                    }
                }
            } else {
                // Connection error - offer retry
                Button("Retry") {
                    Task {
                        await dataModel.retryAfterSettingsChange()
                        if dataModel.shouldComplete {
                            onComplete()
                        }
                    }
                }
                Button("Logout", role: .destructive) {
                    Task {
                        await dataModel.logout()
                        onComplete()
                    }
                }
                Button("Cancel", role: .cancel) {
                    // Stay on splash screen with error showing
                }
            }
        } message: {
            Text(dataModel.errorMessage)
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}
