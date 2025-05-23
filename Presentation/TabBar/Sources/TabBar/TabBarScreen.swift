//
//  AppScreen.swift
//  TabBar
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Navigation
import Home
import Search
import Settings

public enum TabBarScreen: Codable, Hashable, Identifiable, CaseIterable {
    case home
    case search
    case settings
    
    public var id: TabBarScreen { self }
}

extension TabBarScreen {
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .home:
            Label("Home", systemImage: "house.fill")
        case .search:
            Label("Search", systemImage: "magnifyingglass")
        case .settings:
            Label("Settings", systemImage: "gear")
        }
    }
    
    @ViewBuilder @MainActor
    var destination: some View {
        switch self {
        case .home:
            HomeView()
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        }
    }
}
