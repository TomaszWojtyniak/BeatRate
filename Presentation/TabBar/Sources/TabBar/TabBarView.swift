//
//  AppTabView.swift
//  TabBar
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Navigation

@MainActor
public struct TabBarView: View {
    @Binding var selection: TabBarScreen?
    
    public init(selection: Binding<TabBarScreen?>) {
        self._selection = selection
    }
    
    public var body: some View {
        TabView(selection: $selection) {
            ForEach(TabBarScreen.allCases) { screen in
                screen.destination
                    .tag(screen as TabBarScreen?)
                    .tabItem { screen.label }
            }
        }
    }
}

#Preview {
    TabBarView(selection: .constant(.home))
}
