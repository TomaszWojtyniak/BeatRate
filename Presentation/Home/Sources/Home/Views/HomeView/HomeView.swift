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
import Analytics

@MainActor
public struct HomeView: View {
    @State private var dataModel: HomeDataModel = HomeDataModel()
    @State private var selectedAlbum: AlbumModel?
    @State private var selectedSection: HomeSection?
    @State private var gridSelectedAlbum: AlbumModel?

    public init() {}

    public var body: some View {
        // ZStack, not Group: Group hands its modifiers to each branch, so
        // onAppear/.task would re-fire on every loading → ready switch.
        ZStack {
            switch dataModel.state {
            case .loading:
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(Color.accentPrimary)
                    Text(.homeLoading)
                        .textStyle(.body, color: .secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()

            case .needsAppleMusicAccess:
                ContentUnavailableView {
                    Label(String(localized: .homeMusicAccessTitle), systemImage: "music.note")
                        .foregroundStyle(Color.primaryText)
                } description: {
                    Text(.homeMusicAccessMessage)
                        .textStyle(.body, color: .secondaryText)
                } actions: {
                    Button(String(localized: .homeMusicAccessOpenSettings)) {
                        dataModel.track(.openSystemSettingsTap)
                        openAppSettings()
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()

            case .empty:
                ContentUnavailableView {
                    Label(String(localized: .homeEmptyTitle), systemImage: "music.note.list")
                        .foregroundStyle(Color.primaryText)
                } description: {
                    Text(.homeEmptyMessage)
                        .textStyle(.body, color: .secondaryText)
                } actions: {
                    Button(String(localized: .homeEmptyRefresh)) {
                        Task { await dataModel.retry() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .meshBackground()

            case .failed:
                ContentUnavailableView {
                    Label(String(localized: .homeLoadFailedTitle), systemImage: "wifi.exclamationmark")
                        .foregroundStyle(Color.primaryText)
                } description: {
                    Text(.homeLoadFailedMessage)
                        .textStyle(.body, color: .secondaryText)
                } actions: {
                    Button(String(localized: .homeLoadFailedRetry)) {
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
                .scrollEdgeEffectStyle(
                    .soft,
                    for: .all
                )
            }
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumDetailsView(album: album)
        }
        .navigationDestination(item: $selectedSection) { section in
            SectionAlbumsGridView(name: section.sectionName, albums: section.albums, selectedAlbum: $gridSelectedAlbum)
                .onAppear { dataModel.track(.screenView(.sectionGrid, ["section": section.analyticsName, "source": AnalyticsScreen.home.rawValue])) }
                .navigationDestination(item: $gridSelectedAlbum) { album in
                    AlbumDetailsView(album: album)
                }
        }
        .onChange(of: selectedAlbum) { _, album in
            guard let album else { return }
            let section = dataModel.homeSections.first { $0.albums.contains { $0.id == album.id } }
            dataModel.track(.albumTap(source: .homeSection, albumId: album.id, section: section?.analyticsName))
        }
        .onChange(of: gridSelectedAlbum) { _, album in
            guard let album else { return }
            dataModel.track(.albumTap(source: .sectionGrid, albumId: album.id, section: selectedSection?.analyticsName))
        }
        .onAppear { dataModel.track(.screenView(.home)) }
        .navigationTitle(String(localized: .homeNavigationTitle))
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
