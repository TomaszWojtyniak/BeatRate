//
//  ContentView.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import TabBar
import Login
import Navigation

@MainActor
struct ContentView: View {
    @State var isUserLoggedIn: Bool = true
    @State private var selection: TabBarScreen? = .home
    
    var body: some View {
        if isUserLoggedIn {
            TabBarView(selection: $selection)
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
