//
//  SplashView.swift
//  Splash
//
//  Created by Tomasz Wojtyniak on 11/09/2025.
//

#if os(iOS)
import SwiftUI
import CoreUI
import Onboarding
import Splash

/// Shows what the splash view model decided; the explainer's CTA is its only action.
@MainActor
public struct SplashView: View {
    private let viewModel: SplashViewModel

    public init(viewModel: SplashViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            SplashContentView(retryMessage: viewModel.state.retry.map(Self.message))

            if viewModel.state.phase == .musicExplainer {
                MusicLibraryPermissionExplainerView { viewModel.send(action: .continuePastExplainer) }
                    .transition(.opacity)
            }
        }
        .animation(AppAnimation.smooth, value: viewModel.state.phase)
    }

    /// One full sentence per reason, so it translates as a whole.
    private static func message(_ retry: SplashViewModel.State.Retry) -> String {
        switch retry.reason {
        case .noData: String(localized: .splashRetryingNoData(attempt: retry.attempt, total: retry.of))
        case .connectionError: String(localized: .splashRetryingConnection(attempt: retry.attempt, total: retry.of))
        }
    }
}
#endif
