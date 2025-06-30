//
//  HomeNavigationStack.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 15/06/2025.
//

import SwiftUI

public struct HomeNavigationStack: View {
    
    public init() {
        
    }
    
    public var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview {
    HomeNavigationStack()
}
