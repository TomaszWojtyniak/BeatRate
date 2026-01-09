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
    @State private var dataModel = AccountDataModel()
    
    var body: some View {
        NavigationStack {
            Text("Account view")
        }
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inlineLarge)
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
