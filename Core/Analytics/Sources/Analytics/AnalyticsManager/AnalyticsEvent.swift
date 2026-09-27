//
//  AnalyticsEvent.swift
//  Analytics
//

import FirebaseAnalytics

/// Screen names sent as `screen_name` on `screen_view`, and as the `screen`
/// param on events shared between screens (retry, pull to refresh).
nonisolated public enum AnalyticsScreen: String, Sendable {
    case splash
    case musicLibraryPermission = "music_library_permission"
    case musicPlayerPicker = "music_player_picker"
    case loginPrompt = "login_prompt"
    case home
    case sectionGrid = "section_grid"
    case albumDetails = "album_details"
    case artistDetails = "artist_details"
    case search
    case account
    case accountGuest = "account_guest"
    case editProfile = "edit_profile"
    case favoritesManager = "favorites_manager"
    case favoritesShare = "favorites_share"
    case settings
    case deleteAccount = "delete_account"
}

nonisolated public enum AlbumTapSource: String, Sendable {
    case homeSection = "home_section"
    case sectionGrid = "section_grid"
    case searchResult = "search_result"
    case searchRecent = "search_recent"
    case artist
    case accountSection = "account_section"
    case favorites
}

/// Every analytics event the app sends. Names follow Firebase rules:
/// snake_case, ≤40 chars. No PII in params.
nonisolated public enum AnalyticsEvent: Sendable {
    case screenView(AnalyticsScreen, [String: String] = [:])

    // Global
    case tabSelected(tab: String)
    case albumTap(source: AlbumTapSource, albumId: String, section: String? = nil)
    case retryTap(screen: AnalyticsScreen)
    case pullToRefresh(screen: AnalyticsScreen)

    // Onboarding & login
    case permissionContinueTap
    case musicPlayerSelected(player: String, mode: String)
    case signInAppleTap
    case loginMaybeLaterTap
    case rateLoginRequiredTap(albumId: String)
    case guestSignInTap

    // Home
    case openSystemSettingsTap

    // Search
    case search(albumCount: Int, artistCount: Int)
    case searchScopeChanged(scope: String)
    case artistTap(artistId: String)
    case recentClearConfirm

    // Album details
    case rateAlbum(albumId: String, rating: Double)
    case albumArtistTap(albumId: String)
    case tracklistToggle(expanded: Bool)
    case openInPlayerTap(player: String, albumId: String)

    // Account & favorites
    case editProfileSave
    case favoritesManageTap(source: String)
    case favoriteAdded(albumId: String)
    case favoriteRemoved
    case favoritesSaved(count: Int)
    case favoritesShareImageTap

    // Settings
    case logoutTap
    case deleteAccountConfirm

    // Auth outcomes
    case signUp
    case login
    case loginFailed(errorType: String)
    case logout
    case accountDeleted

    var name: String {
        switch self {
        case .screenView: AnalyticsEventScreenView
        case .tabSelected: "tab_selected"
        case .albumTap: "album_tap"
        case .retryTap: "retry_tap"
        case .pullToRefresh: "pull_to_refresh"
        case .permissionContinueTap: "permission_continue_tap"
        case .musicPlayerSelected: "music_player_selected"
        case .signInAppleTap: "sign_in_apple_tap"
        case .loginMaybeLaterTap: "login_maybe_later_tap"
        case .rateLoginRequiredTap: "rate_login_required_tap"
        case .guestSignInTap: "guest_sign_in_tap"
        case .openSystemSettingsTap: "open_system_settings_tap"
        case .search: AnalyticsEventSearch
        case .searchScopeChanged: "search_scope_changed"
        case .artistTap: "artist_tap"
        case .recentClearConfirm: "recent_clear_confirm"
        case .rateAlbum: "rate_album"
        case .albumArtistTap: "album_artist_tap"
        case .tracklistToggle: "tracklist_toggle"
        case .openInPlayerTap: "open_in_player_tap"
        case .editProfileSave: "edit_profile_save"
        case .favoritesManageTap: "favorites_manage_tap"
        case .favoriteAdded: "favorite_added"
        case .favoriteRemoved: "favorite_removed"
        case .favoritesSaved: "favorites_saved"
        case .favoritesShareImageTap: "favorites_share_image_tap"
        case .logoutTap: "logout_tap"
        case .deleteAccountConfirm: "delete_account_confirm"
        case .signUp: AnalyticsEventSignUp
        case .login: AnalyticsEventLogin
        case .loginFailed: "login_failed"
        case .logout: "logout"
        case .accountDeleted: "account_deleted"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case let .screenView(screen, extra):
            return extra.merging([AnalyticsParameterScreenName: screen.rawValue]) { $1 }
        case let .tabSelected(tab):
            return ["tab": tab]
        case let .albumTap(source, albumId, section):
            var params: [String: Any] = ["source": source.rawValue, "album_id": albumId]
            params["section"] = section
            return params
        case let .retryTap(screen), let .pullToRefresh(screen):
            return ["screen": screen.rawValue]
        case let .musicPlayerSelected(player, mode):
            return ["player": player, "mode": mode]
        case let .rateLoginRequiredTap(albumId), let .albumArtistTap(albumId), let .favoriteAdded(albumId):
            return ["album_id": albumId]
        case let .search(albumCount, artistCount):
            return ["album_count": albumCount, "artist_count": artistCount]
        case let .searchScopeChanged(scope):
            return ["scope": scope]
        case let .artistTap(artistId):
            return ["artist_id": artistId]
        case let .rateAlbum(albumId, rating):
            return ["album_id": albumId, "rating": rating]
        case let .tracklistToggle(expanded):
            return ["expanded": expanded ? "true" : "false"]
        case let .openInPlayerTap(player, albumId):
            return ["player": player, "album_id": albumId]
        case let .favoritesManageTap(source):
            return ["source": source]
        case let .favoritesSaved(count):
            return ["count": count]
        case .signUp, .login:
            return [AnalyticsParameterMethod: "apple"]
        case let .loginFailed(errorType):
            return ["error_type": errorType]
        default:
            return [:]
        }
    }
}
