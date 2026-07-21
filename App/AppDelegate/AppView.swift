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
                    await dataModel.getCurrentUser()
                    dataModel.setUserId()
                }
            } else if dataModel.isUserLoggedIn && musicPlayerManager.current == nil {
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
