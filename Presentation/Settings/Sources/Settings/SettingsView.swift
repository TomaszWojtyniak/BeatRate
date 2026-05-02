//
//  SettingsView.swift
//  Settings
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import CoreUI

@MainActor
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dataModel = SettingsDataModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    Section {
                        HStack {
                            Image("apple_music_logo_icon", bundle: .module)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 25)
                                .clipShape(Circle())

                            Text("Apple Music")

                            Spacer()

                            if dataModel.isAppleMusicConnected {
                                Text("Connected")
                            } else {
                                Button("Connect") {
                                    Task {
                                        await dataModel.connectAppleMusic()
                                    }
                                }
                                .disabled(dataModel.isConnectingAppleMusic)
                            }
                        }
                        HStack {
                            Image("spotify_logo_icon", bundle: .module)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 25)
                                .clipShape(Circle())
                            
                            Text("Spotify")
                            
                            Spacer()
                            
                            if dataModel.isSpotifyConnected {
                                Text("Connected")
                            } else {
                                Button("Connect") {
                                    Task {
                                        await dataModel.connectSpotify()
                                    }
                                }
                                .disabled(dataModel.isConnectingSpotify)
                            }
                        }
                    } header: {
                        Text("Accounts")
                    }
                    
                }
                .listStyle(.automatic)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 88)
                }

                VStack(spacing: 0) {
                    Spacer()

                    Button {
                        dataModel.showLogoutConfirmation = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                        .textStyle(.bodyEmphasis, color: .primaryTextOnDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: Size.signInButton)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.95), Color.red.opacity(0.78)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .appShadow(.destructive)
                    }
                    .disabled(dataModel.isLoggingOut)
                    .opacity(dataModel.isLoggingOut ? 0.6 : 1.0)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                await dataModel.loadUserProfile()
            }
        }
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
        }

    }
}

#Preview {
    SettingsView()
}
