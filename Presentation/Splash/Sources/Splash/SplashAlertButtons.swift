//
//  SplashAlertButtons.swift
//  Splash
//

import SwiftUI

struct SplashAlertButtons: View {
    let alertType: AlertType?
    let onOpenSettings: () -> Void
    let onRetry: () -> Void
    let onLogout: () -> Void
    let onReconnectSpotify: () -> Void
    let onSkipSpotify: () -> Void

    var body: some View {
        switch alertType {
        case .musicKitDenied:
            Button("Open Settings", action: onOpenSettings)
            Button("Try Again", action: onRetry)
            Button("Cancel", role: .cancel, action: onLogout)

        case .spotifyReconnect:
            Button("Reconnect Spotify", action: onReconnectSpotify)
            Button("Skip", action: onSkipSpotify)

        case .connectionError, .none:
            Button("Retry", action: onRetry)
            Button("Logout", role: .destructive, action: onLogout)
            Button("Cancel", role: .cancel) {}
        }
    }
}
