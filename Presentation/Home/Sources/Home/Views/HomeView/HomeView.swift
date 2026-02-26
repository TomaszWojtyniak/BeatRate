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

@MainActor
public struct HomeView: View {
    @State private var dataModel: HomeDataModel = HomeDataModel()
    @State private var selectedAlbum: AlbumModel?

    public init() {}

    public var body: some View {
        Group {
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
        .navigationTitle(String(localized: "home.navigation.title", bundle: .module))
        .toolbarTitleDisplayMode(.inlineLarge)
        .task(priority: .userInitiated) {
            // High priority - user is waiting for initial home screen load
            await self.dataModel.loadInitialData()
        }
    }
}

#Preview {
    HomeView()
}
