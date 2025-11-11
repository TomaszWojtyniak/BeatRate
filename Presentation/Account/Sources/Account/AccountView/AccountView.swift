//
//  AccountView.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Settings

struct AccountView: View {
    
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            Text("Account view")
        }
        .navigationBarTitle("Account", displayMode: .automatic)
        .toolbar {
            ToolbarItem {
                Button("Settings", systemImage: "gear") {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    AccountView()
}
