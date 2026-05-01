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
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text("Loading your library...")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 18) {
                        LazyVStack(spacing: 18) {
                            ForEach(self.dataModel.homeSections) { section in
                                HomeSectionView(name: section.sectionName, albums: section.albums, selectedAlbum: $selectedAlbum)
                                    .padding(20)
                                    .roundedMaterialBackground()
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .meshBackground()
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
