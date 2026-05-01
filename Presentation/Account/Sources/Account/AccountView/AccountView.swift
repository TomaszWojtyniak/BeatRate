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
                GlassEffectContainer(spacing: 18) {
                    LazyVStack(spacing: 18) {
                        profileCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        if dataModel.isShowingAlbumRatingsSection {
                            HomeSectionView(
                                name: "Ratings",
                                albums: dataModel.ratedAlbums,
                                selectedAlbum: $selectedAlbum
                            )
                            .padding(20)
                            .roundedMaterialBackground()
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                    .opacity(dataModel.isLoading ? 0 : 1)
                }
            }

            if dataModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    .scaleEffect(1.3)
            }
        }
        .meshBackground()
        .transaction { $0.animation = nil }
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
                        .frame(width: 84, height: 84)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                        )
                        .appShadow(.accentGlow)

                    Text(initials)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)
                }
                .padding(.bottom, 14)

                Text(displayName)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Color.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let email = dataModel.userProfile?.email, dataModel.fullName != nil {
                    Text(email)
                        .font(.system(.footnote))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 2)
                }

                // Gradient "Edit profile" pill
                Button {
                    dataModel.isShowingEditSheet = true
                } label: {
                    Text("Edit profile")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimaryGradient)
                        )
                        .appShadow(.accentGlow)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                // Mini-stats
                HStack {
                    Spacer()
                    miniStat(value: "\(dataModel.ratedAlbums.count)", label: "Rated", color: Color.accentSecondary)
                    Spacer()
                    miniStat(value: "—", label: "Avg", color: Color.accentPrimary)
                    Spacer()
                }
                .padding(.top, 22)
                .padding(.horizontal, 4)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.horizontal, 4)
                }
                .padding(.top, 18)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .roundedMaterialBackground()
    }

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
        }
    }
}

#Preview {
    AccountView()
}
