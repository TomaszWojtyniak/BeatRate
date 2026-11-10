import Analytics
import Models
import Testing
@testable import Home

@MainActor
struct HomeDataModelTests {
    private let useCases = StubHomeUseCases()
    private let analytics: AnalyticsManager
    private let backend: StubAnalyticsBackend
    private let model: HomeDataModel

    private static let album = AlbumModel(
        id: "a",
        appleMusicAlbumData: AppleMusicAlbumData(id: "a", title: "Album", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil),
        firebaseAlbumData: nil
    )
    private static let sections = [HomeSection(name: "New", analyticsName: "new", albums: [album])]

    init() {
        (analytics, backend) = makeAnalytics()
        model = HomeDataModel(analyticsManager: analytics, getHomeUseCase: useCases, setHomeUseCase: useCases)
    }

    @Test func `home starts out loading`() {
        #expect(model.state == .loading)
    }

    @Test func `loaded sections make home ready`() async {
        useCases.results = [.success(Self.sections)]

        await model.loadInitialData()

        #expect(model.state == .ready)
        #expect(model.homeSections.map(\.name) == ["New"])
    }

    // An empty backend is not an outage; telling the user to check their connection would mislead them.
    @Test func `successful fetch with nothing in it is empty, not failed`() async {
        await model.loadInitialData()

        #expect(model.state == .empty)
    }

    @Test func `first fetch failing is a failure`() async {
        useCases.results = [.failure(StubError())]

        await model.loadInitialData()

        #expect(model.state == .failed)
    }

    @Test func `failed refresh keeps the feed on screen`() async {
        useCases.results = [.success(Self.sections), .failure(StubError())]
        await model.loadInitialData()

        await model.refreshData()

        #expect(model.state == .ready)
        #expect(model.homeSections.count == 1)
    }

    @Test func `retry reloads and is tracked`() async {
        useCases.results = [.failure(StubError()), .success(Self.sections)]
        await model.loadInitialData()

        await model.retry()

        #expect(model.state == .ready)
        #expect(backend.logged(.retryTap(screen: .home)))
    }

    @Test(arguments: [false, true])
    func `pull to refresh clears the cache and reloads even if clearing fails`(clearFails: Bool) async {
        useCases.failsToClear = clearFails
        useCases.results = [.success(Self.sections)]

        await model.refreshData()

        #expect(useCases.clearCount == 1)
        #expect(useCases.fetchCount == 1)
        #expect(model.state == .ready)
        #expect(backend.logged(.pullToRefresh(screen: .home)))
    }

    @Test func `album tap is attributed to its section`() async {
        useCases.results = [.success(Self.sections)]
        await model.loadInitialData()

        model.trackHomeAlbumTap(Self.album)
        model.track(.screenView(.home))

        #expect(backend.logged(.albumTap(source: .homeSection, albumId: "a", section: "new")))
        #expect(backend.logged(.screenView(.home)))
    }

    @Test func `tap on an album outside the feed has no section`() {
        model.trackHomeAlbumTap(Self.album)

        #expect(backend.logged(.albumTap(source: .homeSection, albumId: "a", section: nil)))
    }
}
