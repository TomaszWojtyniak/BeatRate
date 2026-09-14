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
import UIKit

@MainActor
public struct HomeView: View {
    @State private var dataModel: HomeDataModel = HomeDataModel()
    @State private var selectedAlbum: AlbumModel?
    @State private var selectedSection: HomeSection?
    @State private var gridSelectedAlbum: AlbumModel?

    public init() {}

    public var body: some View {
        Group {
            switch dataModel.state {
            case .loading:
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text("Loading your library...")
                        .textStyle(.body, color: .secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()

            case .needsAppleMusicAccess:
                ContentUnavailableView {
                    Label("Apple Music Access Needed", systemImage: "music.note")
                        .foregroundStyle(Color.primaryText)
                } description: {
                    Text("BeatRate uses the Apple Music catalog for album artwork, tracklists and release details. Turn it on in Settings to fill your feed.")
                        .textStyle(.body, color: .secondaryText)
                } actions: {
                    Button("Open Settings") { openAppSettings() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()

            case .failed:
                ContentUnavailableView {
                    Label("Couldn't Load Your Feed", systemImage: "wifi.exclamationmark")
                        .foregroundStyle(Color.primaryText)
                } description: {
                    Text("Check your connection and try again.")
                        .textStyle(.body, color: .secondaryText)
                } actions: {
                    Button("Try Again") {
                        Task { await dataModel.retry() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()

            case .ready:
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

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    HomeView()
}
