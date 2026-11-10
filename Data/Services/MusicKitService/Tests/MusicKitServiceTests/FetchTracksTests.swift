import Foundation
import Testing
@testable import MusicKitService

@MainActor
struct FetchTracksTests {

    private static let firstPage = AppleMusicAPI.albumTracks(storefront: "pl", albumId: "1")
    private static let nextPath = "/v1/catalog/pl/albums/1/tracks?offset=300"
    private static let secondPage = AppleMusicAPI.nextPage(nextPath)!

    private func service(_ dataSource: StubAppleMusicDataSource) -> MusicKitService {
        MusicKitService(analyticsManager: .shared, dataSource: dataSource)
    }

    @Test func `tracks from a single page come back in order`() async throws {
        let dataSource = StubAppleMusicDataSource(pages: [Self.firstPage: TracksFixture.page([("a", "One"), ("b", "Two")])])

        let tracks = try await service(dataSource).fetchTracks(albumId: "1")

        #expect(tracks.map(\.title) == ["One", "Two"])
    }

    @Test func `pagination is followed until there is no next page`() async throws {
        let dataSource = StubAppleMusicDataSource(pages: [
            Self.firstPage: TracksFixture.page([("a", "One")], next: Self.nextPath),
            Self.secondPage: TracksFixture.page([("b", "Two")]),
        ])

        let tracks = try await service(dataSource).fetchTracks(albumId: "1")

        #expect(tracks.map(\.id) == ["a", "b"])
        #expect(await dataSource.requestedURLs == [Self.firstPage.absoluteString, Self.secondPage.absoluteString])
    }

    @Test func `storefront is looked up once per service`() async throws {
        let dataSource = StubAppleMusicDataSource(pages: [Self.firstPage: TracksFixture.page([])])
        let service = service(dataSource)

        _ = try await service.fetchTracks(albumId: "1")
        _ = try await service.fetchTracks(albumId: "1")

        #expect(await dataSource.countryCodeCount == 1)
    }

    @Test func `storefront failure fails the track fetch`() async {
        let dataSource = StubAppleMusicDataSource(failsCountryCode: true)

        await #expect(throws: StubError.self) { try await service(dataSource).fetchTracks(albumId: "1") }
    }

    @Test func `failed page request fails the track fetch`() async {
        await #expect(throws: StubError.self) { try await service(StubAppleMusicDataSource()).fetchTracks(albumId: "1") }
    }

    @Test func `malformed page fails the track fetch`() async {
        let dataSource = StubAppleMusicDataSource(pages: [Self.firstPage: Data("{}".utf8)])

        await #expect(throws: DecodingError.self) { try await service(dataSource).fetchTracks(albumId: "1") }
    }

    @Test func `empty search term does not hit the catalog`() async throws {
        let service = service(StubAppleMusicDataSource())

        #expect(try await service.searchAlbums(searchTerm: "").isEmpty)
        #expect(try await service.search(searchTerm: "") == .empty)
    }
}
