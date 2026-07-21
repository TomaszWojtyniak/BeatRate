//
//  AccountDataModel.swift
//  Account
//
//  Created by Tomasz Wojtyniak on 11/11/2025.
//

import SwiftUI
import LoginUseCases
import AccountUseCases
import CoreApp
import Models
import OSLog

@MainActor
@Observable
final class AccountDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let setLoginUseCase: SetLoginUseCaseProtocol
    private let getAccountUseCase: GetAccountUseCaseProtocol
    private let musicPlayerManager: MusicPlayerManager

    var userProfile: FirebaseUserProfile?
    var ratedAlbums: [AlbumModel] = []
    var recentlyListenedAlbums: [AlbumModel] = []
    var isLoading = false
    var isShowingEditSheet = false
    var errorMessage: String?
    var isShowingAlbumRatingsSection: Bool = false
    var isShowingRecentlyListenedSection: Bool = false
    /// Whether the initial full load has succeeded; re-appears only refresh
    /// the cheap slices after that instead of refetching everything.
    private(set) var hasLoaded = false

    var fullName: String? {
        guard let firstName = userProfile?.firstName,
              let lastName = userProfile?.lastName else { return nil }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         setLoginUseCase: SetLoginUseCaseProtocol = SetLoginUseCase(),
         getAccountUseCase: GetAccountUseCaseProtocol = GetAccountUseCase(),
         musicPlayerManager: MusicPlayerManager = .shared) {
        self.getLoginUseCase = getLoginUseCase
        self.setLoginUseCase = setLoginUseCase
        self.getAccountUseCase = getAccountUseCase
        self.musicPlayerManager = musicPlayerManager
    }

    /// The user's main player, surfaced for the view so it doesn't reach for the
    /// manager itself.
    var mainMusicPlayer: MusicPlayer? {
        musicPlayerManager.current
    }

    func loadUserData() async {
        isLoading = true
        defer { isLoading = false }
        await fetchAllData()
    }

    /// Full reload without the blocking spinner — used by pull-to-refresh,
    /// where the system already shows its own indicator.
    func refresh() async {
        await fetchAllData()
    }

    /// Ratings can change while the user is elsewhere in the app (rating an
    /// album), so re-appearing refreshes just this cheap slice silently and
    /// leaves the expensive recently-listened lookup cached.
    func refreshRatedAlbums() async {
        do {
            let albums = try await getAccountUseCase.getUserRatedAlbums()
            self.ratedAlbums = albums
            self.isShowingAlbumRatingsSection = !albums.isEmpty
        } catch {
            // Keep showing the cached ratings rather than surfacing an error.
            Logger.account.error("Failed to refresh rated albums: \(error)")
        }
    }

    private func fetchAllData() async {
        do {
            // Get user ID
            guard let userId = try await getAccountUseCase.getCurrentUserId() else {
                Logger.account.error("No user ID found")
                return
            }

            // Fetch user profile, rated albums, and recently listened albums in parallel.
            async let profileTask = getLoginUseCase.getUserProfile(userId: userId)
            async let ratedAlbumsTask = getAccountUseCase.getUserRatedAlbums()
            async let recentsTask = fetchRecentlyListenedAlbums()

            let (profile, albums, recents) = try await (profileTask, ratedAlbumsTask, recentsTask)

            self.userProfile = profile
            self.ratedAlbums = albums
            self.recentlyListenedAlbums = recents
            self.isShowingRecentlyListenedSection = !recents.isEmpty
            self.isShowingAlbumRatingsSection = !albums.isEmpty
            self.hasLoaded = true

            Logger.account.info("Loaded user profile, \(albums.count) rated albums, \(recents.count) recently listened")
        } catch {
            Logger.account.error("Failed to load user data: \(error)")
            errorMessage = "Failed to load user data"
        }
    }

    func reloadRecentlyListenedAlbums() async {
        let recents = await fetchRecentlyListenedAlbums()
        self.recentlyListenedAlbums = recents
        self.isShowingRecentlyListenedSection = !recents.isEmpty
    }

    private func fetchRecentlyListenedAlbums() async -> [AlbumModel] {
        guard let player = musicPlayerManager.current else {
            Logger.account.info("No main music player selected; skipping recently listened")
            return []
        }

        do {
            return try await getAccountUseCase.getRecentlyListenedAlbums(for: player)
        } catch {
            Logger.account.error("Failed to load recently listened albums: \(error)")
            return []
        }
    }

    func saveUserProfile(firstName: String, lastName: String) async {
        do {
            guard let userId = try await getAccountUseCase.getCurrentUserId() else {
                Logger.account.error("No user ID found")
                return
            }

            let updatedProfile = FirebaseUserProfile(
                email: userProfile?.email,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                hasAppleMusicSubscription: userProfile?.hasAppleMusicSubscription
            )

            try await setLoginUseCase.saveUserProfile(userId: userId, profile: updatedProfile)
            self.userProfile = updatedProfile
            Logger.account.info("User profile updated successfully")
        } catch {
            Logger.account.error("Failed to save user profile: \(error)")
            errorMessage = "Failed to save profile"
        }
    }
}
