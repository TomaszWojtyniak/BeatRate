import Analytics
import Foundation
import Models
import Testing
@testable import Account

@MainActor
struct FavoritesManagerModelTests {
    private let search = StubSearchUseCase()
    private let backend: StubAnalyticsBackend
    private let analytics: AnalyticsManager

    init() {
        (analytics, backend) = makeAnalytics()
    }

    private func model(_ initial: [AlbumModel] = []) -> FavoritesManagerModel {
        FavoritesManagerModel(initial: initial, getSearchUseCase: search, analyticsManager: analytics, debounce: .zero)
    }

    @Test func `album is added once and tracked`() {
        let model = model()

        model.add(Fixture.appleMusic("a"))
        model.add(Fixture.appleMusic("a"))

        #expect(model.working.map(\.id) == ["a"])
        #expect(model.contains("a"))
        #expect(backend.logged(.favoriteAdded(albumId: "a")))
    }

    @Test func `no more than four favorites can be added`() {
        let model = model((1...4).map { Fixture.album("\($0)") })

        model.add(Fixture.appleMusic("5"))

        #expect(!model.canAddMore)
        #expect(model.working.count == 4)
    }

    @Test func `favorites can be removed and reordered`() {
        let model = model(["a", "b", "c"].map { Fixture.album($0) })

        model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        model.remove(atOffsets: IndexSet(integer: 1))

        #expect(model.working.map(\.id) == ["c", "b"])
        #expect(backend.logged(.favoriteRemoved))
    }

    @Test func `search trims the text and lists matching albums`() async {
        search.results = ["blonde": MusicSearchResults(albums: [Fixture.appleMusic("a")], artists: [])]
        let model = model()
        model.searchText = "  blonde "

        model.search()
        #expect(model.isSearching)
        await model.searchTask?.value

        #expect(model.results.map(\.id) == ["a"])
        #expect(!model.isSearching)
    }

    @Test func `newer search text cancels the waiting search`() async {
        let model = model()
        model.searchText = "bl"
        model.search()
        model.searchText = "blo"

        model.search()
        await model.searchTask?.value

        #expect(search.searchedTerms == ["blo"])
    }

    @Test func `blank search clears the results at once`() async {
        search.results = ["blonde": MusicSearchResults(albums: [Fixture.appleMusic("a")], artists: [])]
        let model = model()
        model.searchText = "blonde"
        model.search()
        await model.searchTask?.value

        model.searchText = "   "
        model.search()

        #expect(model.results.isEmpty)
        #expect(!model.isSearching)
    }

    @Test func `failed search shows no results`() async {
        search.failingTerms = ["oops"]
        let model = model()
        model.searchText = "oops"

        model.search()
        await model.searchTask?.value

        #expect(model.results.isEmpty)
        #expect(!model.isSearching)
    }

    @Test func `screen events are tracked`() {
        model().track(.favoritesShareImageTap)

        #expect(backend.logged(.favoritesShareImageTap))
    }
}
