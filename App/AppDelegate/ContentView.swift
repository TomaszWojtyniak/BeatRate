//
//  ContentView.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import TabBar
import Login

@MainActor
struct ContentView: View {
    @State var isUserLoggedIn: Bool = false
    @State private var selection: TabBarScreen? = .home
    
    var body: some View {
        if isUserLoggedIn {
            TabBarView(selection: $selection)
        } else {
            LoginNavigationStack()
        }
    }
}

#Preview {
    ContentView()
}
