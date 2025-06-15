//
//  AppTabView.swift
//  TabBar
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import CoreUI


@MainActor
public struct TabBarView: View {
    @Binding var selection: TabBarScreen?
    let tabs: [TabBarScreen] = TabBarScreen.allCases
    
    public init(selection: Binding<TabBarScreen?>) {
        self._selection = selection
    }
    
    public var body: some View {
        TabView(selection: $selection) {
            ForEach(tabs) { tab in
                Tab(value: tab, role: tab == TabBarScreen.search ? .search : .none) {
                    tab.destination
                } label: {
                    tab.label
                }
            }
        }
        .tint(Color.honeyYellow)
    }
}

#Preview {
    TabBarView(selection: .constant(.home))
}
