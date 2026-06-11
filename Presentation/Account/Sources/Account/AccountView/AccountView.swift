//
//  AccountView.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import Settings
import Models
import AlbumDetails
import CoreUI
import CoreApp

public struct AccountView: View {

    @State private var showingSettings = false
    @State private var dataModel = AccountDataModel()
    @State private var selectedAlbum: AlbumModel?
    @State private var selectedSection: HomeSection?
    @State private var gridSelectedAlbum: AlbumModel?
    private let musicPlayerManager = MusicPlayerManager.shared

    public init() {}

    private var displayName: String {
        dataModel.fullName ?? dataModel.userProfile?.email ?? ""
    }

    private var initials: String {
        let first = (dataModel.userProfile?.firstName?.first).map { String($0) } ?? ""
        let last = (dataModel.userProfile?.lastName?.first).map { String($0) } ?? ""
        let combined = (first + last).uppercased()
        if !combined.isEmpty { return combined }
        // Fallback to first character of email
        if let initial = dataModel.userProfile?.email?.first {
            return String(initial).uppercased()
        }
        return "?"
    }

    public var body: some View {
        ZStack {
            ScrollView {
                GlassEffectContainer(spacing: Spacing.md) {
                    LazyVStack(spacing: Spacing.md) {
                        profileCard
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.xs)

                        if dataModel.isShowingRecentlyListenedSection {
                            HomeSectionView(
                                name: "Recently Listened",
                                albums: dataModel.recentlyListenedAlbums,
                                selectedAlbum: $selectedAlbum,
                                onSeeAll: {
                                    selectedSection = HomeSection(sectionName: "Recently Listened", albums: dataModel.recentlyListenedAlbums)
                                }
                            )
                            .padding(Spacing.lg)
                            .roundedMaterialBackground()
                            .padding(.horizontal, Spacing.md)
                        }

                        if dataModel.isShowingAlbumRatingsSection {
                            HomeSectionView(
                                name: "Ratings",
                                albums: dataModel.ratedAlbums,
                                selectedAlbum: $selectedAlbum,
                                onSeeAll: {
                                    selectedSection = HomeSection(sectionName: "Ratings", albums: dataModel.ratedAlbums)
                                }
                            )
                            .padding(Spacing.lg)
                            .roundedMaterialBackground()
                            .padding(.horizontal, Spacing.md)
                        }
                    }
                    .padding(.bottom, Spacing.lg)
                    .opacity(dataModel.isLoading ? 0 : 1)
                    // Suppress only the implicit fade tied to isLoading; leave
                    // sheet/navigation transitions alone.
                    .animation(nil, value: dataModel.isLoading)
                }
            }

            if dataModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    .scaleEffect(1.3)
            }
        }
        .refreshable {
            await dataModel.refresh()
        }
        .meshBackground()
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumDetailsNavigationStack(album: album)
        }
        .navigationDestination(item: $selectedSection) { section in
            SectionAlbumsGridView(name: section.sectionName, albums: section.albums, selectedAlbum: $gridSelectedAlbum)
                .navigationDestination(item: $gridSelectedAlbum) { album in
                    AlbumDetailsNavigationStack(album: album)
                }
        }
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem {
                Button("Settings", systemImage: "gear") {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $dataModel.isShowingEditSheet) {
            EditProfileView(
                firstName: dataModel.userProfile?.firstName,
                lastName: dataModel.userProfile?.lastName
            ) { firstName, lastName in
                await dataModel.saveUserProfile(firstName: firstName, lastName: lastName)
            }
        }
        .task {
            if dataModel.hasLoaded {
                // Re-appearing (tab switch, popping back from album details):
                // only ratings are likely stale, and they're a cheap fetch.
                await dataModel.refreshRatedAlbums()
            } else {
                await dataModel.loadUserData()
            }
        }
        .onChange(of: musicPlayerManager.current) {
            // Main player switched (e.g. from Settings) — refresh the section to
            // reflect the newly selected service.
            Task { await dataModel.reloadRecentlyListenedAlbums() }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        ZStack {
            // Soft accent halo above the avatar — clipped to card shape
            Circle()
                .fill(Color.accentPrimarySoft)
                .frame(width: Halo.medium, height: Halo.medium)
                .blur(radius: Blur.haloMedium)
                .offset(y: -80)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Conic-gradient avatar with initials
                ZStack {
                    Circle()
                        .fill(Color.avatarConic)
                        .frame(width: Size.avatar, height: Size.avatar)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: Stroke.thick)
                        )
                        .appShadow(.accentGlow)

                    Text(initials)
                        .textStyle(.avatarInitials, color: .white) // intentional white-on-conic
                }
                .padding(.bottom, Spacing.sm)

                Text(displayName)
                    .textStyle(.displayName)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let email = dataModel.userProfile?.email, dataModel.fullName != nil {
                    Text(email)
                        .textStyle(.caption)
                        .padding(.top, Spacing.xxs)
                }

                // Gradient "Edit profile" pill
                Button {
                    dataModel.isShowingEditSheet = true
                } label: {
                    Text("Edit profile")
                        .textStyle(.bodyEmphasis, color: .primaryTextOnDark)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimaryGradient)
                        )
                        .appShadow(.accentGlow)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.md)

                // Mini-stats
                HStack {
                    Spacer()
                    miniStat(value: "\(dataModel.ratedAlbums.count)", label: "Rated", color: Color.accentSecondary)
                    Spacer()
                    miniStat(value: "—", label: "Avg", color: Color.accentPrimary)
                    Spacer()
                }
                .padding(.top, Spacing.lg)
                .padding(.horizontal, Spacing.xxs)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: Stroke.hairline)
                        .padding(.horizontal, Spacing.xxs)
                }
                .padding(.top, Spacing.md)
            }
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .roundedMaterialBackground()
    }

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(value)
                .textStyle(.statValueCompact, color: color)
            Text(label)
                .textStyle(.label)
        }
    }
}

#Preview {
    AccountView()
}
