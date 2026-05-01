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
                    .frame(width: 320, height: 320)
                    .blur(radius: 40)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.accentPrimaryGradient)
                    .frame(width: 124, height: 124)
                    .overlay(
                        Image(systemName: "star.square.on.square.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(22)
                            .foregroundStyle(Color.white.opacity(0.95))
                    )
                    .appShadow(.accentLift)
            }

            // Wordmark
            Text("login.app.name", bundle: .module)
                .font(.system(size: 42, weight: .bold))
                .tracking(-1.0)
                .foregroundStyle(Color.accentPrimary)
                .padding(.top, 28)

            // Tagline
            Text("Rate every album.")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(Color.secondaryTextOnDark)
                .padding(.top, 6)

            Spacer()

            // Show retry status if retrying — otherwise iOS-style activity indicator
            if dataModel.isRetrying {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text(dataModel.errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.primaryTextOnDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)
            } else {
                ProgressView()
                    .tint(Color.accentPrimary)
                    .padding(.bottom, 24)
            }

            // Build label
            Text("v1.0.3 · BUILD 412")
                .font(.system(.caption2, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.secondaryTextOnDark.opacity(0.7))
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 40)
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
