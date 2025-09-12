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
import CoreUI
import SwiftDataManager

@MainActor
public struct HomeView: View {
    @EnvironmentObject private var swiftDataManager: SwiftDataManager
    @State var dataModel: HomeDataModel = HomeDataModel()
    @State var selectedAlbum: AlbumModel?
    @State var showingAccount = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            if dataModel.isLoadingFromCache && dataModel.homeSections.isEmpty {
                VStack {
                    Text("Loading your library...")
                }
            } else {
                List(self.dataModel.homeSections) { section in
                    HomeSectionView(name: section.sectionName, albums: section.albums, selectedAlbum: $selectedAlbum)
                        .padding(20)
                        .roundedMaterialBackground()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.top, 5)
                    
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(Color.backgroundColor)
                .refreshable {
                    await dataModel.refreshData()
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
        .task {
            await self.dataModel.loadInitialData()
        }
    }
}

#Preview {
    HomeView()
}
