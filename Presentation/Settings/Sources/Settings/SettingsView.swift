//
//  SettingsView.swift
//  Settings
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI

@MainActor
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dataModel = SettingsDataModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Form {
                    // Empty for now - ready for future settings
                }
                .scrollContentBackground(.hidden)

                VStack(spacing: 0) {
                    Spacer()

                    Button {
                        dataModel.showLogoutConfirmation = true
                    } label: {
                        Text("Logout")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(.primary)
                            )
                    }
                    .disabled(dataModel.isLoggingOut)
                    .opacity(dataModel.isLoggingOut ? 0.6 : 1.0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
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
        } message: {
            Text("")
        }

    }
}

#Preview {
    SettingsView()
}
