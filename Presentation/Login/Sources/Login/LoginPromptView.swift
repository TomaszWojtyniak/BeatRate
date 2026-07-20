//
//  LoginPromptView.swift
//  Login
//

import SwiftUI
import Analytics
import AuthenticationServices
import CoreApp
import CoreUI
import OSLog

/// Sheet-sized sign-in / sign-up prompt raised when a guest hits a gated feature.
///
/// Shares `LoginDataModel` — and therefore the exact nonce and
/// `performCompleteLogin` path — with the full-screen `LoginView`. Sign in with
/// Apple covers both signing in and creating an account, so one button serves both.
///
/// Dismissal on success is implicit: `performCompleteLogin` yields `true` into the
/// login-state stream, `AppDataModel` forwards it to `SessionManager.update`, which
/// clears `isPresentingLoginPrompt` and closes this sheet.
@MainActor
public struct LoginPromptView: View {
    private let reason: LoginPromptReason
    @State private var dataModel = LoginDataModel()
    @Environment(\.dismiss) private var dismiss

    public init(reason: LoginPromptReason) {
        self.reason = reason
    }

    // `LocalizedStringKey`, not `String` — `Text(someString)` binds the verbatim
    // initializer and would ship these permanently in English no matter what the
    // string catalog contains.
    private var title: LocalizedStringKey {
        switch reason {
        case .account: "Your account, your taste"
        case .rating: "Rate this album"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch reason {
        case .account:
            "Sign in to keep your ratings, revisit your library and track how your taste changes."
        case .rating:
            "Sign in to score albums on a ten-point scale and build a record of everything you listen to."
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            LogomarkView()
                .padding(.top, Spacing.xl)

            Text(title, bundle: .module)
                .textStyle(.title, color: .primaryTextOnDark)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.lg)

            Text(subtitle, bundle: .module)
                .textStyle(.body, color: .secondaryTextOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

            Spacer(minLength: Spacing.xl)

            if dataModel.isLoading {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Signing in...", bundle: .module)
                        .textStyle(.body, color: .primaryTextOnDark)
                }
                .frame(maxWidth: .infinity, maxHeight: Size.signInButton)
                .padding(Spacing.md)
            } else {
                signInButton
            }

            Button {
                dismiss()
            } label: {
                Text("Maybe later", bundle: .module)
                    .textStyle(.bodyEmphasis, color: .secondaryTextOnDark)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
        }
        .errorAlert(isPresented: $dataModel.isShowingErrorAlert,
                    title: dataModel.errorTitle,
                    message: dataModel.errorMessage)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundGradient)
    }

    private var signInButton: some View {
        SignInWithAppleButton(onRequest: { request in
            Task {
                let nonce = await self.dataModel.getCurrentNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = self.dataModel.sha256(nonce)
            }
        }, onCompletion: { result in
            Task {
                switch result {
                case .success(let authResult):
                    do {
                        try await self.dataModel.performCompleteLogin(authResult: authResult)
                        Logger.login.debug("Complete login successful from prompt (Firebase + local storage)")
                    } catch let error {
                        Logger.login.error("Login from prompt failed: \(error.localizedDescription)")
                        await self.dataModel.handleLoginFailure(error: error)
                    }
                case .failure(let error):
                    // Cancellation is a normal outcome here — the guest can keep browsing.
                    if let authError = error as? ASAuthorizationError,
                       authError.code == .canceled {
                        Logger.login.debug("User cancelled sign in from prompt - no error shown")
                    } else {
                        await self.dataModel.handleLoginFailure(error: error)
                    }
                }
            }
        })
        .signInWithAppleButtonStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: Size.signInButton)
        .clipShape(RoundedRectangle(cornerRadius: Radius.signInButton, style: .continuous))
    }
}

#Preview {
    LoginPromptView(reason: .account)
}
