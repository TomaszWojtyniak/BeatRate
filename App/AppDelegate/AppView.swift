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
    @Query private var sessions: [UserSession]
    @State private var selection: TabBarScreen? = .home
    
    var body: some View {
        if sessions.first?.isLoggedIn == true {
            TabBarView(selection: $selection)
        } else {
            LoginNavigationStack()
        }
    }
}

#Preview {
    AppView()
}
