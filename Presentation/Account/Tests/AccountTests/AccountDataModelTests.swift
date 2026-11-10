import Analytics
import CoreApp
import Foundation
import Models
import Testing
@testable import Account

@MainActor
struct AccountDataModelTests {
    private let login = StubLoginUseCases()
    private let account = StubAccountUseCases()
    private let player = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: UserDefaults(suiteName: "AccountTests.\(UUID())")!))
    private let backend: StubAnalyticsBackend
    private let model: AccountDataModel

    init() {
        let analytics: AnalyticsManager
        (analytics, backend) = makeAnalytics()
        model = AccountDataModel(getLoginUseCase: login, setLoginUseCase: login, getAccountUseCase: account, setAccountUseCase: account, musicPlayerManager: player, analyticsManager: analytics)
    }

    // MARK: - Stats and identity

    // 0 means "not rated" and must never pull the average down.
    @Test(arguments: [
        ([8.0, 9, 10, 7], nil as Double?),
        ([8.0, 9, 10, 7, 6], 8),
        ([8.0, 9, 10, 7, 0], nil),
    ])
    func `average appears only from five real ratings`(ratings: [Double], average: Double?) {
        #expect(AccountDataModel.average(of: ratings) == average)
    }

    @Test func `average is taken from the rated albums`() async {
        account.rated = .success((5...9).map { Fixture.album("\($0)", rating: Double($0)) })

        await model.loadUserData()

        #expect(model.averageRating == 7)
    }

    @Test(arguments: [
        (FirebaseUserProfile(email: "ann@b.c", firstName: "Ann", lastName: "Lee"), "Ann Lee", "AL"),
        (FirebaseUserProfile(email: "ann@b.c", firstName: "Ann", lastName: nil), "ann@b.c", "A"),
        (FirebaseUserProfile(email: "ann@b.c", firstName: nil, lastName: nil), "ann@b.c", "A"),
        (FirebaseUserProfile(email: nil, firstName: nil, lastName: nil), "", "?"),
    ])
    func `name and initials fall back to the email`(profile: FirebaseUserProfile, name: String, initials: String) {
        model.userProfile = profile

        #expect(model.displayName == name)
        #expect(model.initials == initials)
    }

    // MARK: - Loading

    @Test func `full load fills every section`() async {
        player.set(.appleMusic, for: "u")
        login.profile = .success(FirebaseUserProfile(email: "a@b.c", firstName: "Ann", lastName: "Lee"))
        account.rated = .success([Fixture.album("r")])
        account.recentlyListened = .success([Fixture.album("l")])
        account.favorites = .success([Fixture.album("f")])

        await model.loadUserData()

        #expect(model.fullName == "Ann Lee")
        #expect(model.ratedAlbums.map(\.id) == ["r"])
        #expect(model.recentlyListenedAlbums.map(\.id) == ["l"])
        #expect(model.favoriteAlbums.map(\.id) == ["f"])
        #expect(model.isShowingAlbumRatingsSection && model.isShowingRecentlyListenedSection && model.isShowingFavoritesSection)
        #expect(account.sectionPlayers == [.appleMusic])
        #expect(!model.isLoading)
    }

    // Spotify history is Premium-only; an unknown premium flag counts as not Premium.
    @Test(arguments: [(true as Bool?, true), (false, false), (nil, false)])
    func `spotify recents need confirmed premium`(premium: Bool?, readsRecents: Bool) async {
        player.set(.spotify, for: "u")
        login.profile = .success(FirebaseUserProfile(email: nil, firstName: nil, lastName: nil, hasSpotifyPremium: premium))

        await model.loadUserData()

        #expect(account.sectionPlayers == [readsRecents ? .spotify : nil])
    }

    // nil means the fetch failed; what is already on screen stays.
    @Test func `failed section keeps what was shown`() async {
        account.rated = .success([Fixture.album("r")])
        await model.loadUserData()
        account.rated = .failure(StubError())

        await model.refresh()

        #expect(model.ratedAlbums.map(\.id) == ["r"])
        #expect(backend.logged(.pullToRefresh(screen: .account)))
    }

    @Test func `missing user id loads nothing`() async {
        account.userId = nil

        await model.loadUserData()

        #expect(!model.isShowingFavoritesSection)
        #expect(model.errorMessage == nil)
    }

    @Test func `failed profile load reports an error`() async {
        login.profile = .failure(StubError())

        await model.loadUserData()

        #expect(model.errorMessage != nil)
        #expect(!model.isShowingFavoritesSection)
    }

    @Test func `rated albums refresh on their own`() async {
        account.rated = .success([Fixture.album("r")])

        await model.refreshRatedAlbums()

        #expect(model.ratedAlbums.map(\.id) == ["r"])
        #expect(model.isShowingAlbumRatingsSection)
    }

    @Test func `failed rated refresh keeps the cached list`() async {
        account.rated = .success([Fixture.album("r")])
        await model.refreshRatedAlbums()
        account.rated = .failure(StubError())

        await model.refreshRatedAlbums()

        #expect(model.ratedAlbums.map(\.id) == ["r"])
    }

    @Test func `recents reload for the eligible player`() async {
        player.set(.appleMusic, for: "u")
        account.recentlyListened = .success([Fixture.album("l")])

        await model.reloadRecentlyListenedAlbums()

        #expect(model.recentlyListenedAlbums.map(\.id) == ["l"])
        #expect(account.recentsPlayers == [.appleMusic])
    }

    @Test(arguments: [false, true])
    func `recents stay hidden without a player or when the fetch fails`(hasPlayer: Bool) async {
        if hasPlayer { player.set(.appleMusic, for: "u") }
        account.recentlyListened = .failure(StubError())

        await model.reloadRecentlyListenedAlbums()

        #expect(model.recentlyListenedAlbums.isEmpty)
        #expect(!model.isShowingRecentlyListenedSection)
    }

    @Test func `spotify without premium skips the recents fetch`() async {
        player.set(.spotify, for: "u")

        await model.reloadRecentlyListenedAlbums()

        #expect(account.recentsPlayers.isEmpty)
        #expect(model.mainMusicPlayer == .spotify)
    }

    // MARK: - Favorites

    @Test func `favorites are capped at four and saved in order`() async {
        await model.saveFavorites((1...5).map { Fixture.album("\($0)") })

        #expect(model.favoriteAlbums.map(\.id) == ["1", "2", "3", "4"])
        #expect(account.savedFavoriteIds == [["1", "2", "3", "4"]])
        #expect(model.canShareFavorites)
    }

    @Test func `failed favorites save reloads what the server has`() async {
        account.failsToSaveFavorites = true
        account.favorites = .success([Fixture.album("server")])

        await model.saveFavorites([Fixture.album("local")])

        #expect(model.favoriteAlbums.map(\.id) == ["server"])
        #expect(model.errorMessage != nil)
        #expect(!model.canShareFavorites)
    }

    // MARK: - Profile

    // Only names go out: the player and Spotify flags are owned by Settings.
    @Test func `saving the profile sends only the names and clears empty ones`() async {
        model.userProfile = FirebaseUserProfile(email: "a@b.c", firstName: "Old", lastName: "Name", hasSpotifyPremium: true, mainMusicPlayer: "spotify")

        await model.saveUserProfile(firstName: "Ann", lastName: "")

        let sent = login.savedProfiles.first
        #expect(sent?.firstName == "Ann")
        #expect(sent?.lastName == nil)
        #expect(sent?.email == "a@b.c")
        #expect(sent?.mainMusicPlayer == nil)
        #expect(model.userProfile?.hasSpotifyPremium == true)
        #expect(model.fullName == nil)
        #expect(backend.logged(.editProfileSave))
    }

    @Test func `profile is not saved without a user`() async {
        account.userId = nil

        await model.saveUserProfile(firstName: "Ann", lastName: "Lee")

        #expect(login.savedProfiles.isEmpty)
    }

    @Test func `failed profile save reports an error`() async {
        login.failsToSave = true

        await model.saveUserProfile(firstName: "Ann", lastName: "Lee")

        #expect(model.errorMessage != nil)
    }

    @Test func `screen events are tracked`() {
        model.track(.screenView(.account))

        #expect(backend.logged(.screenView(.account)))
    }

    @Test(arguments: [
        ("Ann", "", false, true),
        ("", "Lee", false, true),
        ("", "", false, false),
        ("Ann", "Lee", true, false),
    ])
    func `profile can be saved with one name when no save is running`(first: String, last: String, isSaving: Bool, canSave: Bool) {
        #expect(AccountDataModel.canSaveProfile(firstName: first, lastName: last, isSaving: isSaving) == canSave)
    }
}
