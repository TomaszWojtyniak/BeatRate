import Analytics
import Models
import Testing
@testable import Search

@MainActor
struct SearchDataModelTests {
    private let useCases = StubSearchUseCases()
    private let backend: StubAnalyticsBackend
    private let model: SearchDataModel

    private static let album = AppleMusicAlbumData(id: "a", title: "Blonde", artist: "Frank Ocean", coverUrl: nil, releaseDate: nil, genre: nil)
    private static let artist = AppleMusicArtistData(id: "ar", name: "Frank Ocean", imageUrl: nil, genres: [])

    init() {
        let analytics: AnalyticsManager
        (analytics, backend) = makeAnalytics()
        model = SearchDataModel(
            getSearchUseCase: useCases, getRecentAlbumsUseCase: useCases,
            saveRecentAlbumUseCase: useCases, clearRecentAlbumsUseCase: useCases,
            analyticsManager: analytics, debounce: .zero
        )
    }

    @Test func `results replace the list and the search is tracked`() async {
        useCases.results = ["blonde": MusicSearchResults(albums: [Self.album], artists: [Self.artist])]

        model.searchAlbum(searchTerm: "blonde")
        #expect(model.isLoading)
        await model.searchTask?.value

        #expect(model.albums == [Self.album])
        #expect(model.artists == [Self.artist])
        #expect(model.hasResults)
        #expect(!model.isLoading)
        #expect(backend.logged(.search(albumCount: 1, artistCount: 1)))
    }

    // Typing fast must only ever search for the latest text.
    @Test func `a newer search cancels the one still waiting`() async {
        useCases.results = ["bl": MusicSearchResults(albums: [Self.album], artists: []), "blo": .empty]

        model.searchAlbum(searchTerm: "bl")
        model.searchAlbum(searchTerm: "blo")
        await model.searchTask?.value

        #expect(useCases.searchedTerms == ["blo"])
        #expect(!model.hasResults)
    }

    @Test func `clearing the search text empties the results at once`() async {
        useCases.results = ["blonde": MusicSearchResults(albums: [Self.album], artists: [])]
        model.searchAlbum(searchTerm: "blonde")
        await model.searchTask?.value

        model.searchAlbum(searchTerm: "")

        #expect(!model.hasResults)
        #expect(!model.isLoading)
    }

    @Test func `failed search shows no results`() async {
        useCases.results = ["blonde": MusicSearchResults(albums: [Self.album], artists: [])]
        model.searchAlbum(searchTerm: "blonde")
        await model.searchTask?.value
        useCases.failingTerms = ["oops"]

        model.searchAlbum(searchTerm: "oops")
        await model.searchTask?.value

        #expect(!model.hasResults)
        #expect(!model.isLoading)
    }

    @Test func `recent albums load, grow when one is opened and clear on request`() async {
        useCases.recents = [Self.album]
        await model.loadRecentAlbums()
        #expect(model.recentAlbums == [Self.album])

        let other = AppleMusicAlbumData(id: "b", title: "Channel Orange", artist: "Frank Ocean", coverUrl: nil, releaseDate: nil, genre: nil)
        await model.saveRecentAlbum(other).value
        #expect(model.recentAlbums.map(\.id) == ["b", "a"])

        await model.clearRecentAlbums().value
        #expect(model.recentAlbums.isEmpty)
        #expect(backend.logged(.recentClearConfirm))
    }

    @Test func `screen events are tracked`() {
        model.track(.screenView(.search))

        #expect(backend.logged(.screenView(.search)))
    }
}
