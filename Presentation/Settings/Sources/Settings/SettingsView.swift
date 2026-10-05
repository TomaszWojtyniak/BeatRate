//
//  SettingsView.swift
//  Settings
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import CoreUI
import Models
import CoreApp
import Onboarding
import AuthenticationServices
import Analytics

@MainActor
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dataModel = SettingsDataModel()

    // The site picks Polish or English from the device language.
    private static let privacyPolicyUrl = URL(string: "https://www.beatrateapp.com/privacy")!
    private static let termsUrl = URL(string: "https://www.beatrateapp.com/terms")!

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if dataModel.isLoggedIn {
                    accountSections
                }

                Section {
                    Toggle(String(localized: .settingsPrivacyAnalytics), isOn: $dataModel.isAnalyticsEnabled)
                } header: {
                    Text(.settingsPrivacyTitle)
                } footer: {
                    Text(.settingsPrivacyFooter)
                }

                Section {
                    Link(String(localized: .settingsLegalPrivacyPolicy), destination: Self.privacyPolicyUrl)
                    Link(String(localized: .settingsLegalTerms), destination: Self.termsUrl)
                } header: {
                    Text(.settingsLegalTitle)
                }
                
                if dataModel.isLoggedIn {
                    accountButtons
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: .settingsNavigationTitle))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: .settingsDone)) { dismiss() }
                }
            }
            .task {
                guard dataModel.isLoggedIn else { return }
                await dataModel.loadUserProfile()
            }
        }
        .onAppear { dataModel.track(.screenView(.settings)) }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert(String(localized: .settingsLogoutConfirmTitle), isPresented: $dataModel.showLogoutConfirmation) {
            Button(String(localized: .settingsCancel), role: .cancel) {}
            Button(String(localized: .settingsLogout), role: .destructive) {
                Task {
                    do {
                        try await dataModel.logout()
                        dismiss()
                    } catch {
                        // Error is logged in data model
                    }
                }
            }
            .tint(.red)
        }
        .sheet(isPresented: $dataModel.showDeleteAccountSheet) {
            DeleteAccountSheet(dataModel: dataModel) { dismiss() }
        }
    }

    /// Player, logout and deletion only make sense with an account; guests
    /// reach Settings just for the privacy toggle.
    @ViewBuilder
    private var accountSections: some View {
        // Picking a player connects it, so there is nothing left for a
        // separate "Accounts" section to do — a provider is only ever
        // used while it is the main player.
        Section {
            NavigationLink {
                MusicPlayerPickerView(mode: .change) {
                    Task { await dataModel.loadUserProfile() }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(.settingsPlayerLabel)
                        .textStyle(.bodyEmphasis)

                    Spacer(minLength: Spacing.xs)

                    Text(dataModel.mainMusicPlayer?.displayName ?? String(localized: .settingsPlayerNotSet))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(.settingsPlayerTitle)
        } footer: {
            if let notice = dataModel.spotifyNotice {
                Text(notice)
            }
        }
    }
    
    @ViewBuilder
    private var accountButtons: some View {
        Section {
            Button(role: .destructive) {
                dataModel.track(.logoutTap)
                dataModel.showLogoutConfirmation = true
            } label: {
                Text(.settingsLogout)
            }
            .disabled(dataModel.isLoggingOut)
        }

        Section {
            Button(role: .destructive) {
                dataModel.showDeleteAccountSheet = true
            } label: {
                Text(.settingsDeleteAccount)
            }
            .disabled(dataModel.isDeletingAccount)
        } footer: {
            Text(.settingsDeleteAccountFooter)
        }
    }
}

/// Account deletion is gated behind a fresh Sign in with Apple: it proves recent
/// login for the delete and yields the authorization code needed to revoke the
/// Apple token. On success the whole Settings sheet is dismissed via `onDeleted`.
private struct DeleteAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let dataModel: SettingsDataModel
    let onDeleted: () -> Void

    @State private var errorMessage: String?
    /// Hashed ahead of the tap. `onRequest` is synchronous — assigning the nonce
    /// inside a `Task` there races the request being handed to the system, and a
    /// request that goes out without it fails reauthentication.
    @State private var hashedNonce: String?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)

            Image(systemName: "exclamationmark.triangle.fill")
                .textStyle(.iconPlaceholder, color: Color.errorRed)

            Text(.settingsDeleteAccount)
                .textStyle(.title)

            Text(.settingsDeleteAccountMessage)
                .textStyle(.body, color: .secondaryText)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .textStyle(.caption, color: Color.errorRed)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if dataModel.isDeletingAccount || hashedNonce == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: Size.signInButton, maxHeight: Size.signInButton)
            } else {
                SignInWithAppleButton(.continue, onRequest: { request in
                    dataModel.track(.deleteAccountConfirm)
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = hashedNonce
                }, onCompletion: handleAuthorization)
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, minHeight: Size.signInButton, maxHeight: Size.signInButton)
                .clipShape(RoundedRectangle(cornerRadius: Radius.signInButton, style: .continuous))
            }

            Button(String(localized: .settingsCancel)) { dismiss() }
                .disabled(dataModel.isDeletingAccount)
                .padding(.bottom, Spacing.xs)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .presentationDetents([.large])
        .interactiveDismissDisabled(dataModel.isDeletingAccount)
        .onAppear { dataModel.track(.screenView(.deleteAccount)) }
        .task {
            hashedNonce = dataModel.sha256(await dataModel.getCurrentNonce())
        }
    }

    private func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        Task {
            switch result {
            case .success(let authResult):
                do {
                    try await dataModel.deleteAccount(authResult: authResult)
                    // Dismissing Settings takes this sheet with it; dismissing
                    // both in the same tick is the flaky nested-sheet pattern.
                    onDeleted()
                } catch {
                    // The wipe runs before the auth user is deleted, so a failure
                    // here can leave an emptied-but-live account. Retrying finishes
                    // the job (the second wipe is a no-op), so say so.
                    errorMessage = String(localized: .settingsDeleteAccountError)
                }
            case .failure(let error):
                // Cancellation is a normal outcome — leave the sheet open, no error.
                if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                    return
                }
                errorMessage = String(localized: .settingsDeleteAccountVerifyError)
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SettingsView()
    }
}
