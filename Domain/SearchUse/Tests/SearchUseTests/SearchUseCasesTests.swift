import Models
import Testing
@testable import SearchUse

@MainActor
struct SearchUseCasesTests {
    private let music = StubMusicRepository()
    private let search = StubSearchRepository()
    private static let album = AppleMusicAlbumData(id: "a", title: "Album", artist: "Artist", coverUrl: nil, releaseDate: nil, genre: nil)

    @Test func `empty search term returns nothing without hitting the catalog`() async throws {
        #expect(try await GetSearchUseCase(musicRepository: music).search(searchTerm: "") == .empty)
        #expect(music.searchedTerms.isEmpty)
    }

    @Test func `search term goes to the catalog`() async throws {
        music.searchResults = MusicSearchResults(albums: [Self.album], artists: [])

        let results = try await GetSearchUseCase(musicRepository: music).search(searchTerm: "blonde")

        #expect(results == music.searchResults)
        #expect(music.searchedTerms == ["blonde"])
    }

    @Test func `recent albums are saved, listed and cleared`() async {
        await SaveRecentAlbumUseCase(searchRepository: search).save(album: Self.album)
        let recents = await GetRecentAlbumsUseCase(searchRepository: search).fetchRecentAlbums()
        await ClearRecentAlbumsUseCase(searchRepository: search).clearAll()

        #expect(recents == [Self.album])
        #expect(search.recents.isEmpty)
    }

    // Recents are a convenience; storage trouble must never surface as an error.
    @Test func `recents storage failures are swallowed`() async {
        search.fails = true

        await SaveRecentAlbumUseCase(searchRepository: search).save(album: Self.album)
        let recents = await GetRecentAlbumsUseCase(searchRepository: search).fetchRecentAlbums()
        await ClearRecentAlbumsUseCase(searchRepository: search).clearAll()

        #expect(recents.isEmpty)
        #expect(search.clearCount == 1)
    }
}
