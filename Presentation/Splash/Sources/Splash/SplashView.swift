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

    public var body: some View {
        ZStack {
            SplashContentView(
                isRetrying: dataModel.isRetrying,
                errorMessage: dataModel.errorMessage
            )
            .task { await loadAndCompleteIfReady() }

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

}

#Preview {
    SplashView(onComplete: {})
}
