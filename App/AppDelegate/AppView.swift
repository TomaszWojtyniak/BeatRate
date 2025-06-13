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

@MainActor
struct AppView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataModel = AppDataModel()
    
    @Query private var userSession: [UserSession]
    @State private var selection: TabBarScreen? = .home
    
    var body: some View {
        if userSession.first?.isLoggedIn == true {
            TabBarView(selection: $selection)
                .onAppear {
                    if let userId = userSession.first?.userId {
                        self.dataModel.setUserId(userId)
                    }
                }
        } else {
            LoginNavigationStack()
        }
    }
}

#Preview {
    AppView()
}
