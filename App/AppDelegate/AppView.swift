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
import SwiftData
import Splash

@MainActor
struct AppView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataModel = AppDataModel()
    
    @Query private var user: [User]
    @State private var selection: TabBarScreen? = .home
    @State private var showingSplash = true
    
    var body: some View {
        if let currentUser = user.first, currentUser.isLoggedIn {
            if showingSplash {
                SplashView {
                    withAnimation {
                        showingSplash = false
                    }
                }
                .transition(.opacity)
                .onAppear {
                    dataModel.setUserId(currentUser.userId)
                }
            } else {
                TabBarView(selection: $selection)
                    .environment(\.modelContext, dataModel.context())
            }
        } else {
            LoginNavigationStack()
        }
    }
}

#Preview {
    AppView()
}
