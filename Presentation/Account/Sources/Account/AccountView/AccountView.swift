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

public struct AccountView: View {

    @State private var showingSettings = false
    @State private var dataModel = AccountDataModel()
    @State private var selectedAlbum: AlbumModel?

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

                        if dataModel.isShowingAlbumRatingsSection {
                            HomeSectionView(
                                name: "Ratings",
                                albums: dataModel.ratedAlbums,
                                selectedAlbum: $selectedAlbum
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
        .meshBackground()
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumDetailsNavigationStack(album: album)
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
            await dataModel.loadUserData()
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        ZStack {
            // Soft accent halo above the avatar — clipped to card shape
            Circle()
                .fill(Color.accentPrimarySoft)
                .frame(width: 300, height: 300)
                .blur(radius: 40)
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
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white) // intentional white-on-conic, not a token
                }
                .padding(.bottom, Spacing.sm)

                Text(displayName)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Color.primaryText)
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
                        .frame(height: 0.5)
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
