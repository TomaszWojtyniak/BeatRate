import Analytics
import Models
import Testing
@testable import AlbumDetails

@MainActor
struct AlbumDetailsContainerDataModelTests {
    private let useCases = StubAlbumUseCases()
    private let backend: StubAnalyticsBackend
    private let model: AlbumDetailsContainerDataModel

    init() {
        let analytics: AnalyticsManager
        (analytics, backend) = makeAnalytics()
        model = AlbumDetailsContainerDataModel(albumId: "a", getAlbumByIdUseCase: useCases, analyticsManager: analytics)
    }

    @Test func `found album is shown`() async {
        useCases.albumById = .success(Fixture.album())

        await model.load()

        guard case .loaded(let album) = model.state else { Issue.record("not loaded"); return }
        #expect(album.id == "a")
    }

    @Test func `missing album shows a message`() async {
        await model.load()

        guard case .failed(let message) = model.state else { Issue.record("not failed"); return }
        #expect(!message.isEmpty)
    }

    @Test func `retry loads again and is tracked`() async {
        await model.load()
        useCases.albumById = .success(Fixture.album())

        await model.retry()

        guard case .loaded = model.state else { Issue.record("not loaded"); return }
        #expect(backend.logged(.retryTap(screen: .albumDetails)))
        #expect(model.albumId == "a")
    }
}
