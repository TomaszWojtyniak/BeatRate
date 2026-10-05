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
import Analytics
import Models
import OSLog

@MainActor
@Observable
final class AccountDataModel {
    private let getLoginUseCase: GetLoginUseCaseProtocol
    private let setLoginUseCase: SetLoginUseCaseProtocol
    private let getAccountUseCase: GetAccountUseCaseProtocol
    private let setAccountUseCase: SetAccountUseCaseProtocol
    private let musicPlayerManager: MusicPlayerManager
    private let analyticsManager: AnalyticsManager

    /// A user can curate at most this many favorite albums.
    static let maxFavorites = 4
    /// Below this many ratings the average says too little, so it shows "—".
    static let minRatingsForAverage = 5

    var userProfile: FirebaseUserProfile?
    var ratedAlbums: [AlbumModel] = []
    var recentlyListenedAlbums: [AlbumModel] = []
    var favoriteAlbums: [AlbumModel] = []
    var isLoading = false
    var isShowingEditSheet = false
    var errorMessage: String?
    var isShowingAlbumRatingsSection: Bool = false
    var isShowingRecentlyListenedSection: Bool = false

    /// The Favorites card is shown for any logged-in user once loaded, even when
    /// empty — the empty state is what offers "add albums".
    var isShowingFavoritesSection: Bool { hasLoaded }
    /// The share card is a 2×2 of exactly four covers, so sharing needs a full set.
    var canShareFavorites: Bool { favoriteAlbums.count == Self.maxFavorites }
    /// Whether the initial full load has succeeded; re-appears only refresh
    /// the cheap slices after that instead of refetching everything.
    private(set) var hasLoaded = false

    /// The user's mean rating, `nil` until there are `minRatingsForAverage` ratings.
    var averageRating: Double? { Self.average(of: ratedAlbums.compactMap(\.userRating)) }

    static func average(of ratings: [Double]) -> Double? {
        let ratings = ratings.filter { $0 > 0 }  // 0 means "not rated", as in the album average
        guard ratings.count >= minRatingsForAverage else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    var fullName: String? {
        guard let firstName = userProfile?.firstName,
              let lastName = userProfile?.lastName else { return nil }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    init(getLoginUseCase: GetLoginUseCaseProtocol = GetLoginUseCase(),
         setLoginUseCase: SetLoginUseCaseProtocol = SetLoginUseCase(),
         getAccountUseCase: GetAccountUseCaseProtocol = GetAccountUseCase(),
         setAccountUseCase: SetAccountUseCaseProtocol = SetAccountUseCase(),
         musicPlayerManager: MusicPlayerManager = .shared,
         analyticsManager: AnalyticsManager = .shared) {
        self.getLoginUseCase = getLoginUseCase
        self.setLoginUseCase = setLoginUseCase
        self.getAccountUseCase = getAccountUseCase
        self.setAccountUseCase = setAccountUseCase
        self.musicPlayerManager = musicPlayerManager
        self.analyticsManager = analyticsManager
    }

    func track(_ event: AnalyticsEvent) {
        analyticsManager.log(event)
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
        analyticsManager.log(.pullToRefresh(screen: .account))
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

            // The profile is awaited before the sections because `recentsPlayer`
            // reads the Spotify premium flag off it. Favorites stays parallel, and
            // rated + recently listened still share one user_ratings read inside
            // `getAlbumSections`.
            async let favoritesTask = getAccountUseCase.getFavoriteAlbums()

            // Nothing observable changes until every fetch is done: on pull-to-refresh
            // a redraw mid-flight makes SwiftUI cancel the refresh task, which cancelled
            // the MusicKit request (-999) and emptied the sections.
            let profile = try await getLoginUseCase.getUserProfile(userId: userId)
            let sections = try await getAccountUseCase.getAlbumSections(recentlyListenedFor: recentsPlayer(for: profile))
            let favorites = try await favoritesTask

            // Cancelled anyway (e.g. the user left mid-refresh): the results may be
            // partial, so keep what's on screen.
            guard !Task.isCancelled else { return }

            self.userProfile = profile
            self.ratedAlbums = sections.rated
            self.favoriteAlbums = favorites
            self.isShowingAlbumRatingsSection = !sections.rated.isEmpty
            // `nil` means the fetch failed, not an empty history — keep what's shown.
            if let recents = sections.recentlyListened {
                self.recentlyListenedAlbums = recents
                self.isShowingRecentlyListenedSection = !recents.isEmpty
            }
            self.hasLoaded = true

            Logger.account.info("Loaded user profile, \(sections.rated.count) rated albums, \(sections.recentlyListened?.count ?? 0) recently listened, \(favorites.count) favorites")
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

    /// The player recently-listened may be read from, which is not always the main
    /// player: Spotify history is limited to Premium accounts for now. Apple Music
    /// is unaffected, and a `nil` premium flag counts as not-Premium so the section
    /// stays hidden until a `/me` check has actually confirmed it.
    private func recentsPlayer(for profile: FirebaseUserProfile?) -> MusicPlayer? {
        guard let player = musicPlayerManager.current else { return nil }
        guard player != .spotify || profile?.hasSpotifyPremium == true else { return nil }
        return player
    }

    private func fetchRecentlyListenedAlbums() async -> [AlbumModel] {
        guard let player = recentsPlayer(for: userProfile) else {
            Logger.account.info("No player eligible for recently listened; skipping")
            return []
        }

        do {
            return try await getAccountUseCase.getRecentlyListenedAlbums(for: player)
        } catch {
            // Indistinguishable from "no history" to the user — the section just
            // stays hidden.
            Logger.account.error("Failed to load recently listened albums: \(error)")
            return []
        }
    }

    /// Persists a reordered/edited favorites list. Updates the UI optimistically,
    /// then writes the ordered IDs to Firebase; on failure the list is reloaded
    /// from the server so the UI can't drift from what was actually stored.
    func saveFavorites(_ albums: [AlbumModel]) async {
        let capped = Array(albums.prefix(Self.maxFavorites))
        favoriteAlbums = capped
        do {
            try await setAccountUseCase.setFavoriteAlbums(albumIds: capped.map(\.id))
            Logger.account.info("Saved \(capped.count) favorites")
        } catch {
            Logger.account.error("Failed to save favorites: \(error)")
            errorMessage = "Failed to save favorites"
            // Re-sync with the server so the UI can't drift from what was stored.
            favoriteAlbums = (try? await getAccountUseCase.getFavoriteAlbums()) ?? favoriteAlbums
        }
    }

    func saveUserProfile(firstName: String, lastName: String) async {
        analyticsManager.log(.editProfileSave)
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
