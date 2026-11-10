import Testing
@testable import Analytics

struct AnalyticsEventTests {

    struct Case: Sendable, CustomTestStringConvertible {
        let event: AnalyticsEvent
        let name: String
        let parameters: [String: String]

        var testDescription: String {
            ([name] + parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }).joined(separator: " ")
        }
    }

    static let cases: [Case] = [
        Case(event: .screenView(.albumDetails, ["album_id": "42"]), name: "screen_view",
             parameters: ["screen_name": "album_details", "screen_class": "album_details", "album_id": "42"]),
        Case(event: .tabSelected(tab: "home"), name: "tab_selected", parameters: ["tab": "home"]),
        Case(event: .albumTap(source: .homeSection, albumId: "1", section: "New"), name: "album_tap",
             parameters: ["source": "home_section", "album_id": "1", "section": "New"]),
        Case(event: .albumTap(source: .favorites, albumId: "1"), name: "album_tap",
             parameters: ["source": "favorites", "album_id": "1"]),
        Case(event: .retryTap(screen: .home), name: "retry_tap", parameters: ["screen": "home"]),
        Case(event: .pullToRefresh(screen: .search), name: "pull_to_refresh", parameters: ["screen": "search"]),
        Case(event: .permissionContinueTap, name: "permission_continue_tap", parameters: [:]),
        Case(event: .musicPlayerSelected(player: "spotify", mode: "onboarding"), name: "music_player_selected",
             parameters: ["player": "spotify", "mode": "onboarding"]),
        Case(event: .signInAppleTap, name: "sign_in_apple_tap", parameters: [:]),
        Case(event: .loginMaybeLaterTap, name: "login_maybe_later_tap", parameters: [:]),
        Case(event: .rateLoginRequiredTap(albumId: "7"), name: "rate_login_required_tap", parameters: ["album_id": "7"]),
        Case(event: .guestSignInTap, name: "guest_sign_in_tap", parameters: [:]),
        Case(event: .openSystemSettingsTap, name: "open_system_settings_tap", parameters: [:]),
        Case(event: .search(albumCount: 3, artistCount: 2), name: "search",
             parameters: ["album_count": "3", "artist_count": "2"]),
        Case(event: .searchScopeChanged(scope: "artists"), name: "search_scope_changed", parameters: ["scope": "artists"]),
        Case(event: .artistTap(artistId: "a1"), name: "artist_tap", parameters: ["artist_id": "a1"]),
        Case(event: .recentClearConfirm, name: "recent_clear_confirm", parameters: [:]),
        Case(event: .rateAlbum(albumId: "9", rating: 8.5), name: "rate_album",
             parameters: ["album_id": "9", "rating": "8.5"]),
        Case(event: .albumArtistTap(albumId: "9"), name: "album_artist_tap", parameters: ["album_id": "9"]),
        Case(event: .tracklistToggle(expanded: true), name: "tracklist_toggle", parameters: ["expanded": "true"]),
        Case(event: .tracklistToggle(expanded: false), name: "tracklist_toggle", parameters: ["expanded": "false"]),
        Case(event: .openInPlayerTap(player: "appleMusic", albumId: "9"), name: "open_in_player_tap",
             parameters: ["player": "appleMusic", "album_id": "9"]),
        Case(event: .editProfileSave, name: "edit_profile_save", parameters: [:]),
        Case(event: .favoritesManageTap(source: "account"), name: "favorites_manage_tap", parameters: ["source": "account"]),
        Case(event: .favoriteAdded(albumId: "5"), name: "favorite_added", parameters: ["album_id": "5"]),
        Case(event: .favoriteRemoved, name: "favorite_removed", parameters: [:]),
        Case(event: .favoritesSaved(count: 4), name: "favorites_saved", parameters: ["count": "4"]),
        Case(event: .favoritesShareImageTap, name: "favorites_share_image_tap", parameters: [:]),
        Case(event: .logoutTap, name: "logout_tap", parameters: [:]),
        Case(event: .deleteAccountConfirm, name: "delete_account_confirm", parameters: [:]),
        Case(event: .signUp, name: "sign_up", parameters: ["method": "apple"]),
        Case(event: .login, name: "login", parameters: ["method": "apple"]),
        Case(event: .loginFailed(errorType: "canceled"), name: "login_failed", parameters: ["error_type": "canceled"]),
        Case(event: .logout, name: "logout", parameters: [:]),
        Case(event: .accountDeleted, name: "account_deleted", parameters: [:]),
    ]

    @Test(arguments: cases)
    func `every event sends its Firebase name and parameters`(_ testCase: Case) {
        let parameters = testCase.event.parameters

        #expect(testCase.event.name == testCase.name)
        #expect(parameters.mapValues { "\($0)" } == testCase.parameters)
    }

    @Test func `counts and ratings are sent as numbers so GA can aggregate them`() {
        #expect(AnalyticsEvent.search(albumCount: 3, artistCount: 2).parameters["album_count"] as? Int == 3)
        #expect(AnalyticsEvent.rateAlbum(albumId: "9", rating: 8.5).parameters["rating"] as? Double == 8.5)
        #expect(AnalyticsEvent.favoritesSaved(count: 4).parameters["count"] as? Int == 4)
    }

    @Test func `screen view extras cannot override the screen name`() {
        let parameters = AnalyticsEvent.screenView(.home, ["screen_name": "spoofed"]).parameters

        #expect(parameters["screen_name"] as? String == "home")
    }
}
