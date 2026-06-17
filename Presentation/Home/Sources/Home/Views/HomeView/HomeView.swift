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
    @State private var selectedSection: HomeSection?
    @State private var gridSelectedAlbum: AlbumModel?

    public init() {}

    public var body: some View {
        Group {
            if dataModel.isLoadingFromCache && dataModel.homeSections.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text("Loading your library...")
                        .textStyle(.body, color: .secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: Spacing.md) {
                        LazyVStack(spacing: Spacing.md) {
                            ForEach(self.dataModel.homeSections) { section in
                                HomeSectionView(
                                    name: section.sectionName,
                                    albums: section.albums,
                                    selectedAlbum: $selectedAlbum,
                                    onSeeAll: { selectedSection = section }
                                )
                                .padding(Spacing.lg)
                                .roundedMaterialBackground()
                                .padding(.horizontal, Spacing.md)
                            }
                        }
                        .padding(.bottom, Spacing.lg)
                    }
                }
                .meshBackground()
                .refreshable {
                    await dataModel.refreshData()
                }
            }
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumDetailsView(album: album)
        }
        .navigationDestination(item: $selectedSection) { section in
            SectionAlbumsGridView(name: section.sectionName, albums: section.albums, selectedAlbum: $gridSelectedAlbum)
                .navigationDestination(item: $gridSelectedAlbum) { album in
                    AlbumDetailsView(album: album)
                }
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
