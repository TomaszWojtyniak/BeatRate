//
//  LoginView.swift
//  Login
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Analytics
import CoreUI
import AuthenticationServices
import OSLog
import Models
import SwiftData

@MainActor
struct LoginView: View {
    @State private var dataModel: LoginDataModel = LoginDataModel()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logomark with soft accent halo for depth
            ZStack {
                Circle()
                    .fill(Color.accentPrimarySoft)
                    .frame(width: 260, height: 260)
                    .blur(radius: 36)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.accentPrimaryGradient)
                    .frame(width: Size.logomark, height: Size.logomark)
                    .overlay(
                        Image(systemName: "star.square.on.square.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(22)
                            .foregroundStyle(Color.white.opacity(0.95))
                    )
                    .appShadow(.accentLift)
            }

            // App name — large display title
            Text("login.app.name", bundle: .module)
                .textStyle(.displayHero, color: .accentPrimary)
                .padding(.top, Spacing.lg)

            // Tagline
            Text("Rate every album you listen to on a ten-point scale. Keep a record of your taste.")
                .textStyle(.body, color: .secondaryTextOnDark)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, Spacing.sm)

            Spacer()

            if dataModel.isLoading {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Signing in...")
                        .textStyle(.body, color: .primaryTextOnDark)
                }
                .frame(maxWidth: .infinity, maxHeight: 50)
                .padding()
            } else {
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
                                Logger.login.debug("Complete login successful (Firebase + local storage)")
                            } catch let error {
                                Logger.login.error("Login failed: \(error.localizedDescription)")
                                await self.dataModel.handleLoginFailure(error: error)
                            }
                        case .failure(let error):
                            // Check if user simply cancelled - handle silently
                            if let authError = error as? ASAuthorizationError,
                               authError.code == .canceled {
                                Logger.login.debug("User cancelled sign in - no error shown")
                            } else {
                                // Actual error - show to user
                                await self.dataModel.handleLoginFailure(error: error)
                            }
                        }
                    }
                })
                .signInWithAppleButtonStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: Size.signInButton)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
            }
        }
        .errorAlert(isPresented: $dataModel.isShowingErrorAlert,
                    title: dataModel.errorTitle,
                    message: dataModel.errorMessage)
        .padding(.horizontal)
        .padding(.vertical, Spacing.xl)
        .background(Color.backgroundGradient)
    }
}

#Preview {
    LoginView()
}
