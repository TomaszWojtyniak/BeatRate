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
