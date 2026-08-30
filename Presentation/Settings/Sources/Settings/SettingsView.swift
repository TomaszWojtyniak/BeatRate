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

@MainActor
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dataModel = SettingsDataModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        MusicPlayerPickerView(mode: .change)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Text("Player")
                                .textStyle(.bodyEmphasis)

                            Spacer(minLength: Spacing.xs)

                            Text(dataModel.mainMusicPlayer?.displayName ?? "Not set")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Main music player")
                }

                Section {
                    ConnectorRow(
                        iconName: "apple_music_logo_icon",
                        title: "Apple Music",
                        isConnected: dataModel.isAppleMusicConnected,
                        isConnecting: dataModel.isConnectingAppleMusic
                    ) {
                        Task { await dataModel.connectAppleMusic() }
                    }

                    ConnectorRow(
                        iconName: "spotify_logo_icon",
                        title: "Spotify",
                        isConnected: dataModel.isSpotifyConnected,
                        isConnecting: dataModel.isConnectingSpotify
                    ) {
                        Task { await dataModel.connectSpotify() }
                    }
                } header: {
                    Text("Accounts")
                }

                Section {
                    Button(role: .destructive) {
                        dataModel.showDeleteAccountSheet = true
                    } label: {
                        Text("Delete Account")
                    }
                    .disabled(dataModel.isDeletingAccount)
                } footer: {
                    Text("Permanently deletes your account and all your ratings and favorites. This can't be undone.")
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    dataModel.showLogoutConfirmation = true
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .textStyle(.bodyEmphasis, color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .disabled(dataModel.isLoggingOut)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xs)
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await dataModel.loadUserProfile()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Are you sure you want to logout?", isPresented: $dataModel.showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
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

            Text("Delete Account")
                .textStyle(.title)

            Text("This permanently deletes your account and all your ratings and favorites. This can't be undone. Confirm with your Apple ID to continue.")
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
                    .frame(maxWidth: .infinity, minHeight: Size.signInButton)
            } else {
                SignInWithAppleButton(.continue, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = hashedNonce
                }, onCompletion: handleAuthorization)
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, maxHeight: Size.signInButton)
                .clipShape(RoundedRectangle(cornerRadius: Radius.signInButton, style: .continuous))
            }

            Button("Cancel") { dismiss() }
                .disabled(dataModel.isDeletingAccount)
                .padding(.bottom, Spacing.xs)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .presentationDetents([.medium])
        .interactiveDismissDisabled(dataModel.isDeletingAccount)
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
                    errorMessage = "We couldn't finish deleting your account. Please try again."
                }
            case .failure(let error):
                // Cancellation is a normal outcome — leave the sheet open, no error.
                if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                    return
                }
                errorMessage = "Couldn't verify your Apple ID. Please try again."
            }
        }
    }
}

private struct ConnectorRow: View {
    let iconName: String
    let title: String
    let isConnected: Bool
    let isConnecting: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(iconName, bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Size.connectorIcon, height: Size.connectorIcon)
                .clipShape(Circle())

            Text(title)

            Spacer(minLength: Spacing.xs)

            if isConnected {
                Text("Connected")
                    .foregroundStyle(.secondary)
            } else {
                Button(isConnecting ? "Connecting…" : "Connect", action: onConnect)
                    .tint(.accentSecondary)
                    .disabled(isConnecting)
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SettingsView()
    }
}
