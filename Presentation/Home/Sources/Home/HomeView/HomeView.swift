//
//  HomeView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI

@MainActor
public struct HomeView: View {
    
    @State var dataModel: HomeDataModel = HomeDataModel()
    
    public init() {}
    
    public var body: some View {
        VStack {
            List(self.dataModel.homeSections) { section in
                HomeSectionView(name: section.sectionName, albums: section.albums)
                
            }
            .listStyle(.inset)
        }
        .navigationBarTitle("Home", displayMode: .automatic)
        .toolbar {
            ToolbarItem {
                Button("Account", systemImage: "person.crop.circle") {
                    
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
