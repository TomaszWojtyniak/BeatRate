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

    @State private var selection: TabBarScreen? = .home

    var body: some View {
        Group {
            switch dataModel.rootScreen {
            case .splash:
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
            case .playerPicker:
                NavigationStack {
                    MusicPlayerPickerView(mode: .onboarding)
                }
            case .tabs:
                TabBarView(selection: $selection)
                    .onChange(of: selection) { _, tab in dataModel.trackTabSelected(tab) }
                    .alert(Text(.analyticsConsentTitle), isPresented: $dataModel.isAskingAnalyticsConsent) {
                        Button(String(localized: .analyticsConsentDeny)) { dataModel.setAnalyticsConsent(false) }
                        Button(String(localized: .analyticsConsentAllow)) { dataModel.setAnalyticsConsent(true) }
                    } message: {
                        Text(.analyticsConsentMessage)
                    }
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
