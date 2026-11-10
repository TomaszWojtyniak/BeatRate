import Analytics
import Models
import Testing
@testable import ArtistDetails

@MainActor
struct ArtistDetailsDataModelTests {
    private let useCase = StubArtistDetailsUseCase()

    private static func album(_ id: String) -> AppleMusicAlbumData {
        AppleMusicAlbumData(id: id, title: "Album \(id)", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)
    }

    private func model(_ source: ArtistDetailsDataModel.Source) -> (ArtistDetailsDataModel, StubAnalyticsBackend) {
        let (analytics, backend) = makeAnalytics()
        return (ArtistDetailsDataModel(source: source, getArtistDetailsUseCase: useCase, analyticsManager: analytics), backend)
    }

    @Test func `discography is shown latest release first, then albums, then singles`() async {
        useCase.artist = .success(AppleMusicArtistData(
            id: "ar", name: "Artist", imageUrl: nil, genres: [],
            albums: [Self.album("a1"), Self.album("a2")], singles: [Self.album("s1")], latestRelease: Self.album("new")
        ))
        let (model, _) = model(.artistId("ar"))

        model.loadIfNeeded()
        await model.loadTask?.value

        #expect(model.artist?.id == "ar")
        #expect(model.sections.map(\.analyticsName) == ["Latest Release", "Albums", "Singles & EPs"])
        #expect(model.sections.map { $0.albums.map(\.id) } == [["new"], ["a1", "a2"], ["s1"]])
        #expect(!model.isLoading)
        #expect(useCase.lookups == ["id:ar"])
    }

    @Test func `empty groups get no carousel`() async {
        useCase.artist = .success(AppleMusicArtistData(id: "ar", name: "Artist", imageUrl: nil, genres: [], albums: [], singles: nil))
        let (model, _) = model(.albumId("al"))

        model.loadIfNeeded()
        await model.loadTask?.value

        #expect(model.sections.isEmpty)
        #expect(useCase.lookups == ["album:al"])
    }

    @Test func `failed load is flagged and can be retried`() async {
        let (model, _) = model(.artistId("ar"))

        model.loadIfNeeded()
        await model.loadTask?.value
        #expect(model.loadFailed)

        useCase.artist = .success(AppleMusicArtistData(id: "ar", name: "Artist", imageUrl: nil, genres: []))
        model.loadIfNeeded()
        await model.loadTask?.value
        #expect(!model.loadFailed)
        #expect(model.artist != nil)
    }

    @Test func `loaded artist is not fetched again`() async {
        useCase.artist = .success(AppleMusicArtistData(id: "ar", name: "Artist", imageUrl: nil, genres: []))
        let (model, _) = model(.artistId("ar"))
        model.loadIfNeeded()
        await model.loadTask?.value

        model.loadIfNeeded()
        await model.loadTask?.value

        #expect(useCase.lookups.count == 1)
    }

    @Test func `screen events are tracked`() {
        let (model, backend) = model(.artistId("ar"))

        model.track(.artistTap(artistId: "ar"))

        #expect(backend.logged(.artistTap(artistId: "ar")))
    }
}
