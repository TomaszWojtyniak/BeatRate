//
//  AppView.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import TabBar
import Login
import Models
import Splash
import Onboarding
import CoreApp

@MainActor
struct AppView: View {
    @State private var dataModel = AppDataModel()
    private let musicPlayerManager = MusicPlayerManager.shared

    @State private var selection: TabBarScreen? = .home

    var body: some View {
        Group {
            if dataModel.showingSplash {
                SplashView {
                    withAnimation {
                        dataModel.showingSplash = false
                    }
                }
                .transition(.opacity)
                .task {
                    // Reads local storage directly, so this is correct for a guest
                    // (no user, no analytics identity) without racing
                    // `checkInitialLoginStatus()`.
                    await dataModel.getCurrentUser()
                    dataModel.setUserId()
                }
            } else if dataModel.isUserLoggedIn && musicPlayerManager.current == nil {
                // Picking a main player only makes sense once there's an account to
                // key it against. A guest keeps `current == nil`, which the play-link
                // resolver already treats as Apple Music.
                NavigationStack {
                    MusicPlayerPickerView(mode: .onboarding)
                }
            } else {
                TabBarView(selection: $selection)
            }
        }
        .sheet(isPresented: $dataModel.isPresentingLoginPrompt) {
            LoginPromptView(reason: dataModel.loginPromptReason)
                .presentationDragIndicator(.visible)
        }
        .task {
            await dataModel.checkInitialLoginStatus()
            dataModel.startObservingLoginState()
        }
    }
}

#Preview {
    AppView()
}
