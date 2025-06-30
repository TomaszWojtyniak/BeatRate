//
//  HomeView.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import SwiftUI
import Models
import AlbumDetails
import Account

@MainActor
public struct HomeView: View {
    
    @State var dataModel: HomeDataModel = HomeDataModel()
    @State var selectedAlbum: Album?
    @State var showingAccount = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List(self.dataModel.homeSections) { section in
                HomeSectionView(name: section.sectionName, albums: section.albums, selectedAlbum: $selectedAlbum)
                
            }
            .listStyle(.inset)
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumDetailsNavigationStack(album: album)
        }
        .navigationBarTitle("Home", displayMode: .automatic)
        .toolbar {
            ToolbarItem {
                Button("Account", systemImage: "person.crop.circle") {
                    showingAccount = true
                }
            }
        }
        .sheet(isPresented: $showingAccount) {
            AccountNavigationStack()
        }
    }
}

#Preview {
    HomeView()
}
