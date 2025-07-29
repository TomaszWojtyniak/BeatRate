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
import CoreApp

@MainActor
public struct HomeView: View {
    
    @State var dataModel: HomeDataModel = HomeDataModel()
    @State var selectedAlbum: AlbumModel?
    @State var showingAccount = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List(self.dataModel.homeSections) { section in
                HomeSectionView(name: section.sectionName, albums: section.albums, selectedAlbum: $selectedAlbum)
                
            }
            .listStyle(.inset)
            .refreshable {
                Task {
                    await self.dataModel.getMusicData()
                }
            }
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumDetailsNavigationStack(album: album)
        }
        .navigationBarTitle(String(localized: "home.navigation.title", bundle: .module), displayMode: .automatic)
        .toolbar {
            ToolbarItem {
                Button("account.button.name", systemImage: "person.crop.circle") {
                    showingAccount = true
                }
            }
        }
        .sheet(isPresented: $showingAccount) {
            AccountNavigationStack()
        }
        .onFirstAppear {
            Task {
                await self.dataModel.authorizeMusicKit()
                await self.dataModel.getMusicData()
            }
        }
    }
}

#Preview {
    HomeView()
}
