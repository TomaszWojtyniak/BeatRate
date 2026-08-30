//
//  SplashView.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

import SwiftUI
import CoreUI
import Onboarding

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
        ZStack {
            SplashContentView(
                isRetrying: dataModel.isRetrying,
                errorMessage: dataModel.errorMessage
            )
            .task { await loadAndCompleteIfReady() }
            .alert(alertTitle, isPresented: isAlertPresented) {
                SplashAlertButtons(
                    alertType: dataModel.alertType,
                    onOpenSettings: handleOpenSettings,
                    onRetry: handleRetry,
                    onLogout: handleLogout
                )
            } message: {
                Text(alertMessage)
            }

            if dataModel.showsMusicKitExplainer {
                MusicLibraryPermissionExplainerView(onContinue: handleExplainerContinue)
                    .transition(.opacity)
            }
        }
        .animation(AppAnimation.smooth, value: dataModel.showsMusicKitExplainer)
    }

    // MARK: - Actions

    private func loadAndCompleteIfReady() async {
        await dataModel.loadInitialData()
        if dataModel.shouldComplete {
            onComplete()
        }
    }

    private func handleExplainerContinue() {
        Task {
            await dataModel.continueAfterExplainer()
            if dataModel.shouldComplete {
                onComplete()
            }
        }
    }

    private func handleRetry() {
        Task {
            await dataModel.retryAfterSettingsChange()
            if dataModel.shouldComplete {
                onComplete()
            }
        }
    }

    private func handleLogout() {
        Task {
            await dataModel.logout()
            onComplete()
        }
    }

    private func handleOpenSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Alert content

    private var alertTitle: String {
        switch dataModel.alertType {
        case .musicKitDenied: "Apple Music Access Required"
        case .connectionError, .none: "Connection Error"
        }
    }

    private var alertMessage: String {
        dataModel.errorMessage
    }
}

#Preview {
    SplashView(onComplete: {})
}
