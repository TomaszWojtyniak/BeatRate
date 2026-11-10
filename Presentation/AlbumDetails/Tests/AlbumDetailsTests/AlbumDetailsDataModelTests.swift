import Analytics
import CoreApp
import Foundation
import Models
import Testing
import UIKit
@testable import AlbumDetails

@MainActor
struct AlbumDetailsDataModelTests {
    private let useCases = StubAlbumUseCases()
    private let session = SessionManager()
    private let player = MusicPlayerManager(userDefaultsManager: UserDefaultsManager(defaults: UserDefaults(suiteName: "AlbumDetailsTests.\(UUID())")!))
    private let backend: StubAnalyticsBackend
    private let analytics: AnalyticsManager

    init() {
        (analytics, backend) = makeAnalytics()
    }

    private func model(_ album: AlbumModel = Fixture.album()) -> AlbumDetailsDataModel {
        AlbumDetailsDataModel(album: album, sessionManager: session, musicPlayerManager: player, getAlbumDetailsUseCase: useCases, analyticsManager: analytics)
    }

    // MARK: - Play button

    // The guard sits above the player switch; it used to leak an Apple Music button to guests.
    @Test(arguments: [MusicPlayer.appleMusic, .spotify])
    func `guests get no play link for any player`(choice: MusicPlayer) async {
        player.set(choice, for: "u")
        let model = model()

        await model.resolvePlayUrl()

        #expect(model.playUrl == nil)
    }

    @Test func `apple music users play the catalog link`() async {
        session.update(isLoggedIn: true)
        let model = model()

        await model.resolvePlayUrl()

        #expect(model.playUrl?.absoluteString == "https://music.apple.com/album/1")
        #expect(model.playPlayer == nil)
    }

    @Test func `spotify users play a spotify search`() async {
        session.update(isLoggedIn: true)
        player.set(.spotify, for: "u")
        let model = model()

        await model.resolvePlayUrl()

        #expect(model.playUrl?.host() == "open.spotify.com")
    }

    @Test func `play label names the users player`() {
        let appleMusicLabel = model().playLabel
        player.set(.spotify, for: "u")

        #expect(model().playLabel != appleMusicLabel)
    }

    // MARK: - Rating

    @Test func `guest is asked to sign in to rate`() {
        let model = model()

        model.requestLoginForRating()

        #expect(!model.isLoggedIn)
        #expect(session.isPresentingLoginPrompt)
        #expect(session.loginPromptReason == .rating)
    }

    @Test func `stored rating is fetched`() async {
        useCases.userRating = .success(7)
        let model = model()

        #expect(await model.fetchUserRating() == 7)
        #expect(!model.isLoading)
    }

    @Test func `failed rating fetch reads as unrated`() async {
        useCases.userRating = .failure(StubError())

        #expect(await model().fetchUserRating() == nil)
    }

    @Test func `new rating is saved with the album details and the stats refresh`() async {
        useCases.updatedAlbum = .success(Fixture.album(avgRating: 8.5))
        let model = model()

        await model.saveAlbumRating(rating: 9)

        #expect(useCases.savedRatings.map(\.rating) == [9])
        #expect(useCases.savedRatings.first?.title == "Blonde")
        #expect(model.album.firebaseAlbumData?.avgRating == 8.5)
        #expect(backend.logged(.rateAlbum(albumId: "a", rating: 9)))
    }

    // Re-tapping your current star would cost a write and an aggregate recompute.
    @Test func `rating that did not change is not saved`() async {
        useCases.userRating = .success(7)
        let model = model()
        _ = await model.fetchUserRating()

        await model.saveAlbumRating(rating: 7)

        #expect(useCases.savedRatings.isEmpty)
    }

    @Test func `failed save rolls the stars back to the last saved rating`() async {
        useCases.userRating = .success(6)
        let model = model()
        _ = await model.fetchUserRating()
        useCases.failsToSave = true
        model.myRating = 9

        await model.saveAlbumRating(rating: 9)

        #expect(model.myRating == 6)
    }

    @Test func `failed stats refresh keeps the album`() async {
        useCases.updatedAlbum = .failure(StubError())
        let model = model()

        await model.refreshAlbumData()

        #expect(model.album.id == "a")
    }

    // MARK: - Tracklist

    @Test func `album that already has tracks is not fetched again`() async {
        useCases.fullAlbum = .success(Fixture.album(tracks: []))
        let model = model(Fixture.album(tracks: [Fixture.track(1)]))

        await model.loadTracksIfNeeded()

        #expect(model.album.appleMusicAlbumData.tracks?.count == 1)
    }

    @Test(arguments: [[Fixture.track(1), Fixture.track(2)], []])
    func `missing tracks are fetched with the full album`(tracks: [Track]) async {
        useCases.fullAlbum = .success(Fixture.album(tracks: tracks))
        let model = model()

        await model.loadTracksIfNeeded()

        #expect(model.album.appleMusicAlbumData.tracks?.count == tracks.count)
    }

    @Test func `failed tracklist fetch keeps the album`() async {
        let model = model()

        await model.loadTracksIfNeeded()

        #expect(model.album.appleMusicAlbumData.tracks == nil)
    }

    // MARK: - Artwork tint

    @Test func `album without a cover gets no tint`() async {
        let model = model()

        await model.loadMeshColors()

        #expect(model.meshPrimary == nil)
    }

    @Test func `cover colours tint the background once`() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).png")
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        try UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let model = model(Fixture.album(coverUrl: url))

        await model.loadMeshColors()
        let first = model.meshPrimary
        await model.loadMeshColors()

        #expect(first != nil)
        #expect(model.meshSecondary != nil)
        #expect(model.meshPrimary == first)
    }

    @Test func `screen events are tracked`() {
        model().track(.tracklistToggle(expanded: true))

        #expect(backend.logged(.tracklistToggle(expanded: true)))
    }
}
